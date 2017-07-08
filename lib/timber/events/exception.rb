require "timber/event"
require "timber/util"

module Timber
  module Events
    # The exception event is used to track exceptions.
    #
    # @note This event should be installed automatically through integrations,
    #   such as the {Integrations::ActionDispatch::DebugExceptions} integration.
    class Exception < Timber::Event
      MAX_MESSAGE_BYTES = 8192.freeze

      attr_reader :name, :exception_message, :backtrace

      def initialize(attributes)
        @name = attributes[:name] || raise(ArgumentError.new(":name is required"))

        @exception_message = attributes[:exception_message] || raise(ArgumentError.new(":exception_message is required"))
        @exception_message = @exception_message.byteslice(0, MAX_MESSAGE_BYTES)

        backtrace = attributes[:backtrace]
        if backtrace.nil? || backtrace == []
          raise(ArgumentError.new(":backtrace is required"))
        end

        # 10 items max
        @backtrace = backtrace[0..9].collect { |line| parse_backtrace_line(line) }
      end

      def to_hash
        {name: name, message: exception_message, backtrace: backtrace}
      end
      alias to_h to_hash

      # Builds a hash representation containing simple objects, suitable for serialization (JSON).
      def as_json(_options = {})
        {:exception => to_hash}
      end

      def message
        "#{name} (#{exception_message})"
      end

      private
        def parse_backtrace_line(line)
          # using split for performance reasons
          file, line, function_part = line.split(":", 3)

          parsed_line = {file: file}

          if line
            parsed_line[:line] = line.to_i
          end

          if function_part
            _prefix, function_pre = function_part.split("`", 2)
            function = Util::Object.try(function_pre, :chomp, "'")
            parsed_line[:function] = function
          end

          parsed_line
        end
    end
  end
end