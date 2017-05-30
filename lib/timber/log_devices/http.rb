require "base64"
require "msgpack"
require "net/https"

require "timber/config"
require "timber/log_devices/http/dropping_sized_queue"
require "timber/log_devices/http/flushable_sized_queue"


module Timber
  module LogDevices
    # A highly efficient log device that buffers and delivers log messages over HTTPS to
    # the Timber API. It uses batches, keep-alive connections, and msgpack to deliver logs with
    # high-throughput and little overhead. All log preparation and delivery is done asynchronously
    # in a thread as not to block application execution and efficient deliver logs for
    # multi-threaded environments.
    #
    # See {#initialize} for options and more details.
    class HTTP
      TIMBER_STAGING_URL = "https://logs-staging.timber.io/frames".freeze
      TIMBER_PRODUCTION_URL = "https://logs.timber.io/frames".freeze
      TIMBER_URL = ENV['TIMBER_STAGING'] ? TIMBER_STAGING_URL : TIMBER_PRODUCTION_URL
      CONTENT_TYPE = "application/msgpack".freeze
      USER_AGENT = "Timber Ruby/#{Timber::VERSION} (HTTP)".freeze

      # Instantiates a new HTTP log device that can be passed to {Timber::Logger#initialize}.
      #
      # The class maintains a buffer which is flushed in batches to the Timber API. 2
      # options control when the flush happens, `:batch_byte_size` and `:flush_interval`.
      # If either of these are surpassed, the buffer will be flushed.
      #
      # By default, the buffer will apply back pressure when the rate of log messages exceeds
      # the maximum delivery rate. If you don't want to sacrifice app performance in this case
      # you can drop the log messages instead by passing a {DroppingSizedQueue} via the
      # `:request_queue` option.
      #
      # @param api_key [String] The API key provided to you after you add your application to
      #   [Timber](https://timber.io).
      # @param [Hash] options the options to create a HTTP log device with.
      # @option attributes [Symbol] :batch_size (1000) Determines the maximum of log lines in
      #   each HTTP payload. If the queue exceeds this limit an HTTP request will be issued. Bigger
      #   payloads mean higher throughput, but also use more memory. Timber will not accept
      #   payloads larger than 1mb.
      # @option attributes [Symbol] :flush_continuously (true) This should only be disabled under
      #   special circumstsances (like test suites). Setting this to `false` disables the
      #   continuous flushing of log message. As a result, flushing must be handled externally
      #   via the #flush method.
      # @option attributes [Symbol] :flush_interval (1) How often the client should
      #   attempt to deliver logs to the Timber API in fractional seconds. The HTTP client buffers
      #   logs and this options represents how often that will happen, assuming `:batch_byte_size`
      #   is not met.
      # @option attributes [Symbol] :requests_per_conn (2500) The number of requests to send over a
      #   single persistent connection. After this number is met, the connection will be closed
      #   and a new one will be opened.
      # @option attributes [Symbol] :request_queue (SizedQueue.new(3)) The request queue object that queues Net::HTTP
      #   requests for delivery. By deafult this is a `SizedQueue` of size `3`. Meaning once
      #   3 requests are placed on the queue for delivery, back pressure will be applied. IF
      #   you'd prefer to drop messages instead, pass a {DroppingSizedQueue}. See examples for
      #   an example.
      # @option attributes [Symbol] :timber_url The Timber URL to delivery the log lines. The
      #   default is set via {TIMBER_URL}.
      #
      # @example Basic usage
      #   Timber::Logger.new(Timber::LogDevices::HTTP.new("my_timber_api_key"))
      #
      # @example Dropping messages instead of applying back pressure
      #   http_log_device = Timber::LogDevices::HTTP.new("my_timber_api_key",
      #     request_queue: Timber::LogDevices::HTTP::DroppingSizedQueue.new(3))
      #   Timber::Logger.new(http_log_device)
      def initialize(api_key, options = {})
        @api_key = api_key || raise(ArgumentError.new("The api_key parameter cannot be blank"))
        @timber_url = URI.parse(options[:timber_url] || ENV['TIMBER_URL'] || TIMBER_URL)
        @batch_size = options[:batch_size] || 1_000
        @flush_continuously = options[:flush_continuously] != false
        @flush_interval = options[:flush_interval] || 1 # 1 second
        @requests_per_conn = options[:requests_per_conn] || 2_500
        @msg_queue = FlushableSizedQueue.new(@batch_size)
        @request_queue = options[:request_queue] || SizedQueue.new(3)
        @successive_error_count = 0
        @requests_in_flight = 0
      end

      # Write a new log line message to the buffer, and flush asynchronously if the
      # message queue is full. We flush asynchronously because the maximum message batch
      # size is constricted by the Timber API. The actual application limit is a multiple
      # of this. Hence the `@request_queue`.
      def write(msg)
        @msg_queue.enqueue(msg)

        # Lazily start flush threads to ensure threads are alive after forking processes.
        # If the threads are started during instantiation they will not be copied when
        # the current process is forked. This is the case with various web servers,
        # such as phusion passenger.
        ensure_flush_threads_are_started

        if @msg_queue.full?
          debug { "Flushing HTTP buffer via write" }
          flush_async
        end
        true
      end

      # Flush all log messages in the buffer synchronously. This method will not return
      # until delivery of the messages has been successful. If you want to flush
      # asynchronously see {#flush_asyn}.
      def flush
        req = build_request

        if !req.nil?
          http = build_http
          http.start do |conn|
            conn.request(req)
          end
        end

        true
      end

      # Closes the log device, cleans up, and attempts one last delivery.
      def close
        # Kill the flush thread immediately since we are about to flush again.
        @flush_thread.kill if @flush_thread

        # Flush all remaining messages
        flush

        # Kill the request_outlet thread gracefully. We do not want to kill it while a
        # request is inflight. Ideally we'd let it finish before we die.
        if @request_outlet_thread
          4.times do
            if @requests_in_flight == 0 && @request_queue.size == 0
              @request_outlet_thread.kill
              break
            else
              debug do
                "Busy delivering the final log messages, connection will close when complete."
              end
              sleep 1
            end
          end
        end
      end

      private
        def debug_logger
          Timber::Config.instance.debug_logger
        end

        # Convenience method for writing debug messages.
        def debug(&block)
          if debug_logger
            message = yield
            debug_logger.debug(message)
          end
        end

        # This is a convenience method to ensure the flush thread are
        # started. This is called lazily from {#write} so that we
        # only start the threads as needed, but it also ensures
        # threads are started after process forking.
        def ensure_flush_threads_are_started
          if @flush_continuously
            if @request_outlet_thread.nil? || !@request_outlet_thread.alive?
              @request_outlet_thread = Thread.new { request_outlet }
            end

            if @flush_thread.nil? || !@flush_thread.alive?
              @flush_thread = Thread.new { intervaled_flush }
            end
          end
        end

        # Builds an HTTP request based on the current messages queued.
        def build_request
          msgs = @msg_queue.flush
          return if msgs.empty?

          req = Net::HTTP::Post.new(@timber_url.path)
          req['Authorization'] = authorization_payload
          req['Content-Type'] = CONTENT_TYPE
          req['User-Agent'] = USER_AGENT
          req.body = msgs.to_msgpack
          req
        end

        # Flushes the message buffer asynchronously. The reason we provide this
        # method is because the message buffer limit is constricted by the
        # Timber API. The application limit is multiples of the buffer limit,
        # hence the `@request_queue`, allowing us to buffer beyond the Timber API
        # imposed limit.
        def flush_async
          @last_async_flush = Time.now
          req = build_request
          if !req.nil?
            @request_queue.enq(req)
          end
        end

        # Flushes the message queue on an interval. You will notice that {#write} also
        # flushes the buffer if it is full. This method takes note of this via the
        # `@last_async_flush` variable as to not flush immediately after a write flush.
        def intervaled_flush
          # Wait specified time period before starting
          sleep @flush_interval

          loop do
            begin
              if intervaled_flush_ready?
                debug { "Flushing HTTP buffer via the interval" }
                flush_async
              end

              sleep(0.5)
            rescue Exception => e
              debug { "Intervaled HTTP flush failed: #{e.inspect}\n\n#{e.backtrace}" }
            end
          end
        end

        # Determines if the loop in {#intervaled_flush} is ready to be flushed again. It
        # uses the `@last_async_flush` variable to ensure that a flush does not happen
        # too rapidly ({#write} also triggers a flush).
        def intervaled_flush_ready?
          @last_async_flush.nil? || (Time.now.to_f - @last_async_flush.to_f).abs >= @flush_interval
        end

        # Builds an `Net::HTTP` object to deliver requests over.
        def build_http
          http = Net::HTTP.new(@timber_url.host, @timber_url.port)
          http.set_debug_output(debug_logger) if debug_logger
          http.use_ssl = true if @timber_url.scheme == 'https'
          http.read_timeout = 30
          http.ssl_timeout = 10
          http.open_timeout = 10
          http
        end

        # Creates a loop that processes the `@request_queue` on an interval.
        def request_outlet
          loop do
            http = build_http

            begin
              debug { "Starting HTTP connection" }

              http.start do |conn|
                deliver_requests(conn)
              end
            rescue => e
              debug { "#request_outlet error: #{e.message}" }
            ensure
              debug { "Finishing HTTP connection" }
              http.finish if http.started?
            end
          end
        end

        # Creates a loop that delivers requests over an open (kept alive) HTTP connection.
        # If the connection dies, the request is thrown back onto the queue and
        # the method returns. It is the responsibility of the caller to implement retries
        # and establish a new connection.
        def deliver_requests(conn)
          num_reqs = 0

          while num_reqs < @requests_per_conn
            debug { "Waiting on next request, threads waiting: #{@request_queue.num_waiting}" }

            # Blocks waiting for a request.
            req = @request_queue.deq
            @requests_in_flight += 1

            begin
              resp = conn.request(req)
            rescue => e
              debug { "#deliver_request error: #{e.message}" }

              @successive_error_count += 1

              # Back off so that we don't hammer the Timber API.
              calculated_backoff = @successive_error_count * 2
              backoff = calculated_backoff > 30 ? 30 : calculated_backoff

              debug { "Backing off #{backoff} seconds, error ##{@successive_error_count}" }

              sleep backoff

              # Throw the request back on the queue for a retry
              @request_queue.enq(req)
              return false
            ensure
              @requests_in_flight -= 1
            end

            @successive_error_count = 0
            num_reqs += 1
            debug { "Request successful: #{resp.code}" }
          end
        end

        # Builds the `Authorization` header value for HTTP delivery to the Timber API.
        def authorization_payload
          @authorization_payload ||= "Basic #{Base64.urlsafe_encode64(@api_key).chomp}"
        end
    end
  end
end