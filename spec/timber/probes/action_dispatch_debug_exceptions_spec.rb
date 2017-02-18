require "spec_helper"

describe Timber::Probes::ActionDispatchDebugExceptions do
  describe "#{described_class}::*InstanceMethods" do
    describe "#log_error" do
      let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }
      let(:io) { StringIO.new }
      let(:logger) do
        logger = Timber::Logger.new(io)
        logger.level = ::Logger::DEBUG
        logger
      end

      around(:each) do |example|
        class ExceptionController < ActionController::Base
          layout nil

          def index
            raise "boom"
          end

          def method_for_action(action_name)
            action_name
          end
        end

        ::RailsApp.routes.draw do
          get 'exception' => 'exception#index'
        end

        Timecop.freeze(time) { example.run }

        Object.send(:remove_const, :ExceptionController)
      end

      it "should set the context" do
        mock_class
        dispatch_rails_request("/exception")
        # Because constantly updating the line numbers sucks :/
        expect(io.string).to include("RuntimeError (boom):\\n\\n")
        expect(io.string).to include("@metadata")
        expect(io.string).to include("\"event\":{\"server_side_app\":{\"exception\":{\"name\":\"RuntimeError\",\"message\":\"boom\",\"backtrace\":[\"")
      end

      def mock_class
        klass = defined?(::ActionDispatch::DebugExceptions) ? ::ActionDispatch::DebugExceptions : ::ActionDispatch::ShowExceptions
        allow_any_instance_of(klass).to receive(:logger).and_return(logger)
      end
    end
  end
end