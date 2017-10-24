require "socket"
require "time"

require "timber/contexts"
require "timber/events"

module Timber
  # Represents a new log entry into the log. This is an intermediary class between
  # `Logger` and the log device that you set it up with.
  class LogEntry #:nodoc:
    BINARY_LIMIT_THRESHOLD = 1_000.freeze
    DT_PRECISION = 6.freeze
    MESSAGE_MAX_BYTES = 8192.freeze
    SCHEMA = "https://raw.githubusercontent.com/timberio/log-event-json-schema/v3.2.0/schema.json".freeze

    attr_reader :context_snapshot, :event, :level, :message, :progname, :tags, :time, :time_ms

    # Creates a log entry suitable to be sent to the Timber API.
    # @param level [Integer] the log level / severity
    # @param time [Time] the exact time the log message was written
    # @param progname [String] the progname scope for the log message
    # @param message [String] Human readable log message.
    # @param context_snapshot [Hash] structured data representing a snapshot of the context at
    #   the given point in time.
    # @param event [Timber.Event] structured data representing the log line event. This should be
    #   an instance of {Timber.Event}.
    # @return [LogEntry] the resulting LogEntry object
    def initialize(level, time, progname, message, context_snapshot, event, options = {})
      @level = level
      @time = time.utc
      @progname = progname

      # If the message is not a string we call inspect to ensure it is a string.
      # This follows the default behavior set by ::Logger
      # See: https://github.com/ruby/ruby/blob/trunk/lib/logger.rb#L615
      @message = message.is_a?(String) ? message : message.inspect
      @message = @message.byteslice(0, MESSAGE_MAX_BYTES)
      @tags = options[:tags]
      @time_ms = options[:time_ms]
      @context_snapshot = context_snapshot
      @event = event
    end

    # Builds a hash representation containing simple objects, suitable for serialization (JSON).
    def as_json(options = {})
      options ||= {}
      hash = {
        :level => level,
        :dt => formatted_dt,
        :message => message,
        :tags => tags,
        :time_ms => time_ms
      }

      if !event.nil?
        hash[:event] = event.as_json
      end

      if !context_snapshot.nil? && context_snapshot.length > 0
        hash[:context] = context_snapshot
      end

      hash[:"$schema"] = SCHEMA

      hash = if options[:only]
        hash.select do |key, _value|
          options[:only].include?(key)
        end
      elsif options[:except]
        hash.select do |key, _value|
          !options[:except].include?(key)
        end
      else
        hash
      end

      # Preparing a log event for JSON should remove any blank values. Timber strictly
      # validates incoming data, including message size. Blank values will fail validation.
      # Moreover, binary data (ASCII-8BIT) generally cannot be encoded into JSON because it
      # contains characters outside of the valid UTF-8 space.
      Util::Hash.deep_reduce(hash) do |k, v, h|
        # Discard blank values
        if !v.nil? && (!v.respond_to?(:length) || v.length > 0)
          # If the value is a binary string, give it special treatment
          if v.respond_to?(:encoding) && v.encoding == ::Encoding::ASCII_8BIT
            # Only keep binary values less than a certain size. Sizes larger than this
            # are almost always file uploads and data we do not want to log.
            if v.length < BINARY_LIMIT_THRESHOLD
              # Attempt to safely encode the data to UTF-8
              encoded_value = encode_string(v)
              if !encoded_value.nil?
                h[k] = encoded_value
              end
            end
          else
            # Keep all other values
            h[k] = v
          end
        end
      end
    end

    def inspect
      to_s
    end

    def to_json(options = {})
      as_json(options).to_json
    end

    def to_msgpack(*args)
      as_json.to_msgpack(*args)
    end

    # This is used when LogEntry objects make it to a non-Timber logger.
    def to_s
      log_message = message

      if !event.nil?
        event_hash = event.as_json
        event_type = event_hash.keys.first

        event_type = if event.is_a?(Events::Custom)
          "#{event_type}.#{event.type}"
        else
          "#{event_type}"
        end

        log_message = "#{message} [#{event_type}]"
      end

      log_message + "\n"
    end

    private
      def formatted_dt
        @formatted_dt ||= time.iso8601(DT_PRECISION)
      end

      # Attempts to encode a non UTF-8 string into UTF-8, discarding invalid characters.
      # If it fails, a nil is returned.
      def encode_string(string)
        string.encode('UTF-8', {
          :invalid => :replace,
          :undef   => :replace,
          :replace => '?'
        })
      rescue Exception
        nil
      end
  end
end