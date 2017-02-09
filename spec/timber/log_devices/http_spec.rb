require "spec_helper"

describe Timber::LogDevices::HTTP do
  describe "#initialize" do
    it "should initialize properly" do
      http = described_class.new("MYKEY", flush_interval: 0.1)
      thread = http.instance_variable_get(:@flush_thread)
      expect(thread).to be_alive
      thread = http.instance_variable_get(:@flush_thread)
      expect(thread).to be_alive
    end
  end

  describe "#write" do
    let(:http) { described_class.new("MYKEY") }
    let(:msg_queue) { http.instance_variable_get(:@msg_queue) }

    it "should buffer the messages" do
      http.write("test log message")
      expect(msg_queue.flush).to eq(["test log message"])
    end

    context "with a low batch size" do
      let(:http) { described_class.new("MYKEY", :batch_size => 2) }

      it "should attempt a delivery when the limit is exceeded" do
        http.write("test")
        expect(http).to receive(:flush).exactly(1).times
        http.write("my log message")
      end
    end
  end

  describe "#close" do
    let(:http) { described_class.new("MYKEY") }

    it "should kill the threads" do
      http.close
      thread = http.instance_variable_get(:@flush_thread)
      sleep 0.1 # too fast!
      expect(thread).to_not be_alive
      thread = http.instance_variable_get(:@outlet_thread)
      sleep 0.1 # too fast!
      expect(thread).to_not be_alive
    end

    it "should attempt a delivery" do
      message = "a" * 19
      http.write(message)
      expect(http).to receive(:flush).exactly(1).times
      http.close
    end
  end

  # Testing a private method because it helps break down our tests
  describe "#flush" do
    let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }

    it "should add a request to the queue" do
      http = described_class.new("MYKEY", threads: false)
      log_entry = Timber::LogEntry.new("INFO", time, nil, "test log message 1", nil, nil)
      http.write(log_entry)
      log_entry = Timber::LogEntry.new("INFO", time, nil, "test log message 2", nil, nil)
      http.write(log_entry)
      http.send(:flush)
      request_queue = http.instance_variable_get(:@request_queue)
      request = request_queue.deq
      expect(request).to be_kind_of(Net::HTTP::Post)
      expect(request.body).to eq("\x92\x83\xA5level\xA4INFO\xA2dt\xBB2016-09-01T12:00:00.000000Z\xA7message\xB2test log message 1\x83\xA5level\xA4INFO\xA2dt\xBB2016-09-01T12:00:00.000000Z\xA7message\xB2test log message 2".force_encoding("ASCII-8BIT"))

      message_queue = http.instance_variable_get(:@msg_queue)
      expect(message_queue.size).to eq(0)
    end

    it "should preserve formatting for mshpack payloads" do
      http = described_class.new("MYKEY", threads: false)
      http.write("This is a log message 1".to_msgpack)
      http.write("This is a log message 2".to_msgpack)
      http.send(:flush)
    end
  end

  # Testing a private method because it helps break down our tests
  describe "#intervaled_flush" do
    it "should start a intervaled flush thread and flush on an interval" do
      http = described_class.new("MYKEY", flush_interval: 0.1)
      expect(http).to receive(:flush).exactly(1).times
      sleep 0.12 # too fast!
      mock = expect(http).to receive(:flush).exactly(1).times
      sleep 0.12 # too fast!
    end
  end

  # Outlet
  describe "#outlet" do
    let(:time) { Time.utc(2016, 9, 1, 12, 0, 0) }

    it "should start a intervaled flush thread and flush on an interval" do
      stub = stub_request(:post, "https://logs.timber.io/frames").
        with(
          :body => "\x92\x83\xA5level\xA4INFO\xA2dt\xBB2016-09-01T12:00:00.000000Z\xA7message\xB2test log message 1\x83\xA5level\xA4INFO\xA2dt\xBB2016-09-01T12:00:00.000000Z\xA7message\xB2test log message 2".force_encoding("ASCII-8BIT"),
          :headers => {
            'Accept' => 'application/json',
            'Authorization' => 'Basic TVlLRVk=',
            'Content-Type' => 'application/msgpack',
            'User-Agent' => "Timber Ruby/#{Timber::VERSION} (HTTP)"
          }
        ).
        to_return(:status => 200, :body => "", :headers => {})

      http = described_class.new("MYKEY", flush_interval: 0.1)
      log_entry = Timber::LogEntry.new("INFO", time, nil, "test log message 1", nil, nil)
      http.write(log_entry)
      log_entry = Timber::LogEntry.new("INFO", time, nil, "test log message 2", nil, nil)
      http.write(log_entry)
      sleep 0.3

      expect(stub).to have_been_requested.times(1)
    end
  end
end