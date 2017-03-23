# encoding: utf-8

module Timber
  class CLI
    module Messages
      include IOHelper

      extend self

      APP_URL = "https://app.timber.io"
      DOCS_URL = "https://timber.io/docs"
      REPO_URL = "https://github.com/timberio/timber-ruby"
      SUPPORT_EMAIL = "support@timber.io"
      TWITTER_HANDLE = "@timberdotio"
      WEBSITE_URL = "https://timber.io"
      MAX_LENGTH = 80.freeze

      def application_details(app)
        message = <<-MESSAGE
Woot! Your API 🔑  is valid:

Name:      #{app.name} (#{app.environment})
Framework: #{app.framework_type}
Platform:  #{app.platform_type}
MESSAGE
message.rstrip
      end

      def edit_app_url(app)
        "#{APP_URL}"
      end

      def bad_experience_message
message = <<-MESSAGE
Bummer! That is certainly not the experience we were going for.

Could you tell us why you a bad experience?

(this will be sent directly to the Timber engineering team)
MESSAGE
message.rstrip
      end

      def commit_and_deploy_reminder
message = <<-MESSAGE
Last step! Commit and deploy:

    #{colorize("git add config/initializers/timber.rb", :blue)}
    #{colorize("git commit -am 'Install Timber'", :blue)}

    #{colorize("push and deploy", :blue)} 🚀
MESSAGE
message.rstrip
end

      def console_url(app)
message = <<-MESSAGE
Your console URL: https://app.timber.io/organizations/timber/apps/#{app.slug}/console
MESSAGE
      end

      def contact
message = <<-MESSAGE
Website:       #{WEBSITE_URL}
Documentation: #{DOCS_URL}
Support:       #{SUPPORT_EMAIL}
MESSAGE
message.rstrip
      end

      def http_environment_variables(api_key)
message = <<-MESSAGE
Great! Add this variable to your environment:

    #{colorize("export TIMBER_API_KEY=\"#{api_key}\"", :blue)}

MESSAGE
message.rstrip
      end

      def free_data
message = <<-MESSAGE
As a welcome gift, we've credited your account with ✨ 50mb✨. Get more:

* Get ✨ 250mb✨ for tweeting your experience to #{TWITTER_HANDLE}
* Get ✨ 100mb✨ for starring our repo: #{REPO_URL}
* Get ✨ 100mb✨ for following #{TWITTER_HANDLE} on twitter
MESSAGE
message.rstrip
end

      def header
message = <<-MESSAGE
🌲 Timber.io Ruby Installer

 ^  ^  ^   ^      ___I_      ^  ^   ^  ^  ^   ^  ^
/|\\/|\\/|\\ /|\\    /\\-_--\\    /|\\/|\\ /|\\/|\\/|\\ /|\\/|\\
/|\\/|\\/|\\ /|\\   /  \\_-__\\   /|\\/|\\ /|\\/|\\/|\\ /|\\/|\\
/|\\/|\\/|\\ /|\\   |[]| [] |   /|\\/|\\ /|\\/|\\/|\\ /|\\/|\\
MESSAGE
message.rstrip
      end

      def heroku_install(app)
message = <<-MESSAGE
To send logs from Heroku please run this command in a separate window:

    #{colorize("heroku drains:add #{app.heroku_drain_url}", :blue)}

MESSAGE
message.rstrip
      end

      def no_api_key_provided
message = <<-MESSAGE
Hey there! Welcome to Timber. In order to proceed, you'll need an API key.
If you already have one, you can run this installer like:

    #{colorize("bundle exec timber install my-api-key", :blue)}

#{obtain_key_instructions}
MESSAGE
        message.rstrip
      end

      def obtain_key_instructions
message = <<-MESSAGE
Don't have a key? Head over to:

    #{colorize("https://app.timber.io", :blue)}

Once there, create an application. Your API key will be displayed afterwards.
For more detailed instructions, checkout our docs page:

https://timber.io/docs/app/obtain-api-key/

If you're confused, don't hesitate to contact us: #{SUPPORT_EMAIL}

MESSAGE
message.rstrip
      end

      def separator
        "--------------------------------------------------------------------------------"
      end

      def spinner(iteration)
        rem = iteration % 3
        case rem
        when 0
          "/"
        when 1
          "-"
        when 2
          "\\"
        end
      end

      def success
        "✓ Success!"
      end

      def task_complete(message)
        remainder = MAX_LENGTH - message.length - success.length

        dots = "." * remainder
        "\r#{message}#{dots}#{success}"
      end

      def task_start(message)
        remainder = MAX_LENGTH - message.length - success.length

        "\r#{message}" + ("." * remainder)
      end

      def we_love_you_too
        "Thanks! We 💖 you too!"
      end
    end
  end
end