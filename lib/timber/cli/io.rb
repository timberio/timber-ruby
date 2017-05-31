require "timber/cli/io/ansi"
require "timber/cli/io/messages"

module Timber
  class CLI
    # This is an abstraction for interfacing with IO devices. By default
    # it uses the STDOUT and STDIN io devices, but can be passed other devices
    # upon initialization.
    class IO
      attr_reader :io_out, :io_in
      attr_accessor :api

      def initialize(options = {})
        @io_out = options[:io_out] || STDOUT
        @io_in = options[:io_in] || STDIN
      end

      def ask(prompt, allowed_inputs, options = {}, iteration = 0)
        if api
          api.event(:waiting_for_input, prompt: prompt)
        end

        write prompt + " "
        input = gets.downcase

        if api
          event_prompt = options[:event_prompt] || prompt
          api.event(:received_input, prompt: event_prompt, value: input)
        end

        if allowed_inputs.include?(input)
          input
        else
          if iteration == 10
            raise "It appears we're having an issue receiving correct input for:\n\n" \
              "#{prompt}\n\n" \
              "We were expecting one of #{allowed_inputs}, but got #{input.inspect}."
          else
            puts "Woops! That's not a valid input. Please enter one of #{allowed_inputs.join(", ")}."
            ask(prompt, allowed_inputs, options, iteration + 1)
          end
        end
      end

      def ask_to_proceed
        message = "Ready to proceed?"
        case ask_yes_no(message)
        when :yes
          true
        when :no
          ask_to_proceed
        end
      end

      def ask_yes_no(message, options = {})
        case ask(message + " (y/n)", ["y", "n"], options)
        when "y"
          :yes
        when "n"
          :no
        end
      end

      def gets
        value = io_in.gets
        value ? value.chomp.downcase : ""
      end

      def puts(message, color = nil)
        if color
          message = ANSI.colorize(message, color)
        end

        io_out.puts(message)
      end

      def task(message, &block)
        write IO::Messages.task_start(message), :blue
        result = yield
        puts IO::Messages.task_complete(message), :green
        result
      rescue Exception => e
        puts IO::Messages.task_failed(message), :red
        raise e
      end

      def write(message, color = nil)
        if color
          message = ANSI.colorize(message, color)
        end

        io_out.write(message)
      end
    end
  end
end