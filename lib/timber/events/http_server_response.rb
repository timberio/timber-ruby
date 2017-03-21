module Timber
  module Events
    # The HTTP server response event tracks outgoing HTTP responses that you send
    # to clients.
    #
    # @note This event should be installed automatically through integrations,
    #   such as the {Integrations::ActionController::LogSubscriber} integration.
    class HTTPServerResponse < Timber::Event
      attr_reader :body, :headers, :request_id, :status, :time_ms

      def initialize(attributes)
        @body = Util::HTTPEvent.normalize_body(attributes[:body])
        @headers = Util::HTTPEvent.normalize_headers(attributes[:headers])
        @request_id = attributes[:request_id]
        @status = attributes[:status] || raise(ArgumentError.new(":status is required"))
        @time_ms = attributes[:time_ms] || raise(ArgumentError.new(":time_ms is required"))
        @time_ms = @time_ms.round(6)
      end

      def to_hash
        {body: body, headers: headers, request_id: request_id, status: status, time_ms: time_ms}
      end
      alias to_h to_hash

      def as_json(_options = {})
        {:server_side_app => {:http_server_response => to_hash}}
      end

      def message
        "Completed #{status} #{status_description} in #{time_ms}ms"
      end

      def status_description
        Rack::Utils::HTTP_STATUS_CODES[status]
      end
    end
  end
end