begin
  require "lograge"
rescue Exception
end

require "timber/cli/file_helper"
require "timber/cli/installer"
require "timber/cli/io_helper"

module Timber
  class CLI
    module Installers
      class Rails < Installer
        include IOHelper

        # Runs the installer.
        def run(app, api)
          # Ask all of the questions up front. These values get cached.
          development_preference = get_development_preference(api)
          api_key_storage_preference = get_api_key_storage_preference(api)
          should_logrageify = logrageify?(api)

          puts ""
          puts Messages.separator
          puts ""

          if should_logrageify
            logrageify!
          end

          environments.each do |environment|
            if already_configured?(environment)
              environment_file_path = get_environment_file_path(environment)
              message = "Installing the Timber::Logger in #{environment_file_path}"
              puts colorize(Messages.task_complete(message), :green)

              next
            end

            case environment
            when :development
              case development_preference
              when :send
                extra_comment = <<-NOTE
  # Note: When you are done testing, simply instantiate the logger like this:
  #
  #   logger = Timber::Logger.new(STDOUT)
  #
  # Be sure to remove the "log_device =" and "logger =" lines below.
NOTE
                extra_comment = extra_comment.rstrip
                install_http(environment, :inline, api, extra_comment: extra_comment)
              when :dont_send
                install_stdout(environment, api)
              end

            when :test
              # Tests should not be logged by default.
              install_nil(environment, api)

            else
              if app.heroku?
                install_stdout(environment, api)
              else
                install_http(environment, api_key_storage_preference, api)
              end
            end
          end
        end

        private
          def logrageify?(api)
            if true || defined?(::Lograge)
              puts ""
              puts Messages.separator
              puts ""
              puts "We noticed you have lograge installed. Would you like to configure "
              puts "Timber to function similarly?"
              puts "(this silences template renders, sql queries, and controller calls)"
              puts ""
              puts colorize("1) Yes, configure Timber like lograge", :blue)
              puts colorize("2) No, use the Rails logging defaults", :blue)
              puts ""

              case ask("Enter your choice: (1/2)", ["1", "2"], api)
              when "1"
                true
              when "2"
                false
              end
            else
              false
            end
          end

          def logrageify!
            initializer_path = File.join("config", "initializers", "timber.rb")

            task_message = "Logrageifying in #{initializer_path}"
            write Messages.task_start(task_message)

            initializer_content = get_initializer_content(initializer_path)

            if !initializer_content.include?("logrageify!")
              code = "config.logrageify!"
              FileHelper.append(initializer_path, code)
            end

            puts colorize(Messages.task_complete(task_message), :green)
          end

          def get_initializer_content(initializer_path)
            config_code = "config = Timber::Config.instance\n"
            FileHelper.read_or_create(initializer_path, config_code)
          end

          # Traverses the config/environments directory and returns an array of
          # symbols representing the various environments.
          def environments
            path = File.join("config", "environments", "*.rb")
            environment_files = Dir[path]
            environment_files.collect do |file_name|
              File.split(file_name).last.gsub(/\.rb$/, "").to_sym
            end
          end

          # Determines the development preference
          def get_development_preference(api)
            puts ""
            puts Messages.separator
            puts ""
            puts "Would you like to temporarily send development logs to Timber?"
            puts "(Logs will still go to STDOUT, but this provides an easy way"
            puts "to kick the tires. Once you're done testing, you can disable "
            puts "this in config/environments/development.rb)"
            puts ""
            puts colorize("1) Yes, send development logs to Timber", :blue)
            puts colorize("2) No, just print development logs to STDOUIT", :blue)
            puts ""

            case ask("Enter your choice: (1/2)", ["1", "2"], api)
            when "1"
              :send
            when "2"
              :dont_send
            end
          end

          # Determines the API key storage prference (environment variable or inline)
          def get_api_key_storage_preference(api)
            puts ""
            puts Messages.separator
            puts ""
            puts "For production/staging how would you like to store the Timber API key?"
            puts ""
            puts colorize("1) Using environment variables", :blue)
            puts colorize("2) Configured inline in my app", :blue)
            puts ""

            case ask("Enter your choice: (1/2)", ["1", "2"], api)
            when "1"
              puts ""
              puts Messages.http_environment_variables(api.api_key)
              puts ""

              ask_yes_no("Ready to proceed?", api)

              :environment
            when "2"
              :inline
            end
          end

          # Based on the API key storage preference, we generate the proper code.
          def get_api_key_code(storage_type, api_key)
            case storage_type
            when :environment
              "ENV['TIMBER_API_KEY']"
            when :inline
              "'#{api_key}'"
            else
              raise ArgumentError.new("API key storage type not recognized! " \
                "#{storage_type.inspect}")
            end
          end

          # Wraps the logger in TaggedLogging if it is available. Older versions of Rails
          # do not include this constant.
          def config_set_logger_code
            @config_set_logger_code ||= defined?(::ActiveSupport::TaggedLogging) ?
              "ActiveSupport::TaggedLogging.new(logger)" : "logger"
          end

          def install_nil(environment, api)
            environment_file_path = get_environment_file_path(environment)

            logger_code = <<-CODE
  # Install the Timber.io logger but silence all logs (log to nil). We install the
  # logger to ensure the Rails.logger object exposes the proper API.
  logger = Timber::Logger.new(nil)
  logger.level = config.log_level
  config.logger = #{config_set_logger_code}
CODE

            install_logger(environment_file_path, logger_code, api)
          end

          # Installs the Timber logger using the HTTP transport strategy in the
          # specified environment file.
          def install_http(environment, api_key_storage_type, api, options = {})
            environment_file_path = get_environment_file_path(environment)
            api_key_code = get_api_key_code(api_key_storage_type, api.api_key)
            extra_comment = options[:extra_comment]

            logger_code = <<-CODE
  # Install the Timber.io logger, send logs over HTTP.#{extra_comment}
  log_device = Timber::LogDevices::HTTP.new(#{api_key_code})
  logger = Timber::Logger.new(log_device)
  logger.level = config.log_level
  config.logger = #{config_set_logger_code}
CODE

            install_logger(environment_file_path, logger_code, api)
          end

          # Installs the Timber logger using the STDOUT transport method in the specified
          # environment file.
          def install_stdout(environment, api)
            environment_file_path = get_environment_file_path(environment)
            api_key_code = get_api_key_code(api_key_storage_type, api.api_key)

            logger_code = <<-CODE
  # Install the Timber.io logger, send logs over STDOUT. Actual log delivery
  # to the Timber service is handled external of this application.
  logger = Timber::Logger.new(STDOUT)
  logger.level = config.log_level
  config.logger = #{config_set_logger_code}
CODE

            install_logger(environment_file_path, logger_code, api)
          end

          # Determines if the environment is already configured.
          def already_configured?(environment)
            environment_file_path = get_environment_file_path(environment)
            environment_file_contents = get_environment_file_contents(environment_file_path)
            logger_installed?(environment_file_contents)
          end

          # Convenience method for getting the current environment file contents.
          def get_environment_file_contents(environment_file_path)
            File.read(environment_file_path)
          end

          # Determines if the Timber logger is already installed in the environment
          # file contents.
          def logger_installed?(environment_file_contents)
            environment_file_contents.include?("Timber::Logger.new")
          end

          # Installs the Timber logger in the specified environment file with the
          # provided logger code.
          def install_logger(environment_file_path, logger_code, api)
            current_contents = get_environment_file_contents(environment_file_path)

            task_message = "Installing the Timber::Logger in #{environment_file_path}"
            write Messages.task_start(task_message)

            if !logger_installed?(current_contents)
              new_contents = current_contents.sub(/\nend/, "\n\n#{logger_code}\nend")
              File.write(environment_file_path, new_contents)
              api.event!(:file_written, path: environment_file_path)
            end

            puts colorize(Messages.task_complete(task_message), :green)

            true
          end

          # Convenience method for getting an environment's file path. Also verifies
          # that the file actually exists.
          def get_environment_file_path(environment)
            path = File.join("config", "environments", "#{environment}.rb")
            FileHelper.verify(path)
          end
      end
    end
  end
end