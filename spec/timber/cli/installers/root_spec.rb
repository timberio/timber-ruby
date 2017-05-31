require "spec_helper"

describe Timber::CLI::Installers::Root, :rails_23 => true do
  let(:api_key) { "abcd1234" }
  let(:app) do
    attributes = {
      "api_key" => api_key,
      "environment" => "development",
      "framework_type" => "rails",
      "heroku_drain_url" => "http://drain.heroku.com",
      "name" => "My Rails App",
      "platform_type" => "other"
    }
    Timber::CLI::API::Application.new(attributes)
  end
  let(:api) { Timber::CLI::API.new(api_key) }
  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:io) { Timber::CLI::IO.new(io_out: output, io_in: input) }
  let(:installer) { described_class.new(io, api) }

  describe ".run" do
    it "should run properly" do
      input.string = "y\n"

      expect(installer).to receive(:install_platform).with(app).exactly(1).times.and_return(true)
      expect(installer).to receive(:run_sub_installer).with(app).exactly(1).times.and_return(true)
      expect(installer).to receive(:send_test_messages).exactly(1).times.and_return(true)
      expect(installer).to receive(:confirm_log_delivery).exactly(1).times.and_return(true)
      expect(installer).to receive(:assist_with_git).exactly(1).times.and_return(true)
      expect(api).to receive(:event!).with(:success).exactly(1).times
      expect(installer).to receive(:collect_feedback).exactly(1).times.and_return(true)

      expect(installer.run(app)).to eq(true)
    end
  end

  describe ".install_platform" do
    context "non-heroku" do
      it "should do nothing" do
        expect(installer.send(:install_platform, app)).to eq(true)
        expect(output.string).to eq("")
      end
    end

    context "heroku" do
      before(:each) do
        app.platform_type = "heroku"
      end

      it "should prompt for Heroku install" do
        input.string = "y\n"

        expect(installer.send(:install_platform, app)).to eq(true)

        expected_output = "\n--------------------------------------------------------------------------------\n\nFirst, let's setup your Heroku drain. Run this command in a separate window:\n\n    \e[34mheroku drains:add http://drain.heroku.com\e[0m\n    \e[32m(✓ copied to clipboard)\e[0m\n\nReady to proceed? (y/n) "
        expect(output.string).to eq(expected_output)
      end
    end
  end

  describe ".get_sub_installer" do
    context "with Rails" do
      around(:each) do |example|
        if defined?(Rails)
          example.run
        else
          Rails = true
          example.run
          Object.send(:remove_const, :Rails)
        end
      end

      it "should return Rails" do
        expect(installer.send(:get_sub_installer).class).to eq(Timber::CLI::Installers::Rails)
      end
    end

    context "without Rails" do
      around(:each) do |example|
        if defined?(Rails)
          OldRails = Rails
          Object.send(:remove_const, :Rails)
          example.run
          Rails = OldRails
          Object.send(:remove_const, :OldRails)
        else
          example.run
        end
      end

      it "should return other" do
        expect(installer.send(:get_sub_installer).class).to eq(Timber::CLI::Installers::Other)
      end
    end
  end
end