require "logger"
require "singleton"

require "timber/config/integrations"

module Timber
  # Singleton class for reading and setting Timber configuration.
  #
  # For Rails apps, this is installed into `config.timber`. See examples below.
  #
  # @example Rails example
  #   config.timber.append_metadata = false
  # @example Everything else
  #   config = Timber::Config.instance
  #   config.append_metdata = false
  class Config
    # @private
    class NoLoggerError < StandardError; end

    # @private
    class SimpleLogFormatter < ::Logger::Formatter
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        "[Timber] #{String === msg ? msg : msg.inspect}\n"
      end
    end

    DEVELOPMENT_NAME = "development".freeze
    PRODUCTION_NAME = "production".freeze
    STAGING_NAME = "staging".freeze
    TEST_NAME = "test".freeze

    include Singleton

    attr_writer :http_body_limit

    # @private
    def initialize
      @http_body_limit = 2000
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
    def environment=(value)
      @environment = value
    end

    # Accessor method for {#environment=}
    def environment
      @environment ||= ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development"
    end

    # This is a list of header keys that should be filtered. Note, all headers are
    # normalized to down-case. So please _only_ pass down-cased headers.
    #
    # @example Rails
    #   # config/environments/production.rb
    #   config.timber.header_filter_headers += ['api-key']
    def http_header_filters=(value)
      @http_header_filters = value
    end

    # Accessor method for {#http_header_filters=}
    def http_header_filters
      @http_header_filters ||= []
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
    def http_body_limit=(value)
      @http_body_limit = value
    end

    # Accessor method for {#http_body_limit=}
    def http_body_limit
      @http_body_limit
    end

    # Convenience method for accessing the various `Timber::Integrations::*` class
    # settings. These provides settings for enabling, disabled, and silencing integrations.
    # See {Integrations} for a full list of available methods.
    def integrations
      Integrations
    end

    # A convenience method that automatically sets Timber's configuration to closely match
    # the behavior of the ruby lograge library. This makes it easier when transitioning
    # from lograge.
    #
    # It turns this:
    #
    #   Started GET "/" for 127.0.0.1 at 2012-03-10 14:28:14 +0100
    #   Processing by HomeController#index as HTML
    #     Rendered text template within layouts/application (0.0ms)
    #     Rendered layouts/_assets.html.erb (2.0ms)
    #     Rendered layouts/_top.html.erb (2.6ms)
    #     Rendered layouts/_about.html.erb (0.3ms)
    #     Rendered layouts/_google_analytics.html.erb (0.4ms)
    #   Completed 200 OK in 79ms (Views: 78.8ms | ActiveRecord: 0.0ms)
    #
    # Into this:
    #
    #   Get "/" sent 200 OK in 79ms @metadata {...}
    #
    # In other words it:
    #
    # 1. Silences ActiveRecord SQL query logs.
    # 2. Silences ActiveView template rendering logs.
    # 3. Silences ActionController controller call logs.
    # 4. Collapses HTTP request and response logs into a single event.
    #
    # Notice also that is is not exactly like lograge. This is intentional. Lograge has
    # a number of downsides:
    #
    # 1. The attribute names (`method`, `format`, `status`, `db`, etc) are too generalized and vague.
    #    This makes it _very_ likely that it will clash with other structured data you're
    #    logging.
    # 2. It doesn't support context making it near impossible to view in-app logs generated for
    #    the same request.
    def logrageify!
      integrations.action_controller.silence = true
      integrations.action_view.silence = true
      integrations.active_record.silence = true
      integrations.rack.http_events.collapse_into_single_event = true
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

    # @private
    def development?
      environment == DEVELOPMENT_NAME
    end

    # @private
    def test?
      environment == TEST_NAME
    end

    # @private
    def production?
      environment == PRODUCTION_NAME
    end

    # @private
    def staging?
      environment == STAGING_NAME
    end
  end
end