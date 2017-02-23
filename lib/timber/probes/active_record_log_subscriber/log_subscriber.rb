module Timber
  module Probes
    class ActiveRecordLogSubscriber < Probe
      # The log subscriber that replaces the default `ActiveRecord::LogSubscriber`.
      # The intent of this subscriber is to, as transparently as possible, properly
      # track events that are being logged here. This LogSubscriber will never change
      # default behavior / log messages.
      class LogSubscriber < ::ActiveRecord::LogSubscriber #:nodoc:
        def sql(event)
          super(event)

          if @message
            payload = event.payload
            event = Events::SQLQuery.new(
              sql: payload[:sql],
              time_ms: event.duration,
              message: @message
            )

            logger.debug event
          end
        end

        private
          def debug(message)
            @message = message
          end
      end
    end
  end
end