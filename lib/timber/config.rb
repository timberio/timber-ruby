require "logger"
require "singleton"

module Timber
  # Interface for setting and reading Timber configuration.
  #
  # For Rails apps this is installed into `config.timber`. See examples below.
  #
  # @example Rails example
  #   config.timber.append_metadata = false
  # @example Everything else
  #   config = Timber::Config.instance
  #   config.append_metdata = false
  class Config
    class NoLoggerError < StandardError; end

    class SimpleLogFormatter < ::Logger::Formatter
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        "[Timber] #{String === msg ? msg : msg.inspect}\n"
      end
    end

    PRODUCTION_NAME = "production".freeze
    STAGING_NAME = "staging".freeze

    include Singleton

    attr_writer :header_filters, :http_body_limit

    # @private
    def initialize
      @header_filters = []
      @http_body_limit = 2000
    end

    # This determines if the log messages should have metadata appended. Ex:
    #
    #     log message @metadata {...}
    #
    # By default, this is turned on for production and staging environments only. Other
    # environment should set this setting explicitly.
    #
    # @example Rails
    #   config.timber.append_metadata = false
    # @example Everything else
    #   Timber::Config.instance.append_metadata = false
    def append_metadata=(value)
      @append_metadata = value
    end

    # Accessor method for {#append_metadata=}.
    def append_metadata?
      if defined?(@append_metadata)
        return @append_metadata == true
      end

      production? || staging?
    end

    # This is useful for debugging. This Sets a debug_logger to view internal Timber library
    # log messages. The default is `nil`. Meaning log to nothing.
    #
    # See {#debug_to_file} and {#debug_to_stdout} for convenience methods that handle creating
    # and setting the logger.
    #
    # @example Rails
    #   config.timber.debug_logger = ::Logger.new(STDOUT)
    # @example Everything else
    #   Timber::Config.instance.debug_logger = ::Logger.new(STDOUT)
    def debug_logger=(value)
      @debug_logger = value
    end

    # Accessor method for {#debug_logger=}.
    def debug_logger
      @debug_logger
    end

    # A convenience method for writing internal Timber debug messages to a file.
    #
    # @example Rails
    #   config.timber.debug_to_file("#{Rails.root}/log/timber.log")
    # @example Everything else
    #   Timber::Config.instance.debug_to_file("log/timber.log")
    def debug_to_file(file_path)
      unless File.exist? File.dirname path
        FileUtils.mkdir_p File.dirname path
      end
      file = File.open file_path, "a"
      file.binmode
      file.sync = config.autoflush_log
      file_logger = ::Logger.new(file)
      file_logger.formatter = SimpleLogFormatter.new
      self.debug_logger = file_logger
    end

    # A convenience method for writing internal Timber debug messages to STDOUT.
    #
    # @example Rails
    #   config.timber.debug_to_stdout
    # @example Everything else
    #   Timber::Config.instance.debug_to_stdout
    def debug_to_stdout
      stdout_logger = ::Logger.new(STDOUT)
      stdout_logger.formatter = SimpleLogFormatter.new
      self.debug_logger = stdout_logger
    end

    # The environment your app is running in. Defaults to `RACK_ENV` and `RAILS_ENV`.
    # It should be rare that you have to set this. If the aforementioned env vars are not
    # set please do.
    #
    # @example If you do not set `RACK_ENV` or `RAILS_ENV`
    #   Timber::Config.instance.environment = "staging"
    def environment
      @environment ||= ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
    end

    # This is a list of header keys that should be filtered. Note, all headers are
    # normalized to down-case. So please _only_ pass down-cased headers.
    #
    # @example Rails
    #   # config/environments/production.rb
    #   config.timber.filter_headers += ['api-key']
    def header_filters
      @header_filters
    end

    # Truncates captured HTTP bodies to this specified limit. The default is `2000`.
    # If you want to capture more data, you can raise this to a maximum of `5000`,
    # or lower this to be more efficient with data. `2000` characters should give you a good
    # idea of the body content. If you need to raise to `5000` you're only constraint is
    # network throughput.
    #
    # @example Rails
    #   config.timber.http_body_limit = 500
    # @example Everything else
    #   Timber::Config.instance.http_body_limit = 500
    def http_body_limit
      @http_body_limit
    end

    # This is the _main_ logger Timber writes to. All of the Timber integrations write to
    # this logger instance. It should be set to your global logger. For Rails, this is set
    # automatically to `Rails.logger`, you should not have to set this.
    #
    # @example Non-rails frameworks
    #   my_global_logger = Timber::Logger.new(STDOUT)
    #   Timber::Config.instance.logger = my_global_logger
    def logger=(value)
      @logger = value
    end

    # Accessor method for {#logger=}.
    def logger
      if @logger.is_a?(Proc)
        @logger.call()
      else
        @logger ||= Logger.new(STDOUT)
      end
    end

    private
      def production?
        environment == PRODUCTION_NAME
      end

      def staging?
        environment == STAGING_NAME
      end
  end
end