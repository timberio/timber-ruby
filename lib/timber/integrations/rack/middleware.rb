module Timber
  module Integrations
    module Rack
      # Base class that all Rack middlewares extend. See the class level methods for
      # configuration options.
      class Middleware
        class << self
          # Easily enable / disable specific middlewares.
          #
          # @example
          #   Timber::Integrations::Rack::UserContext.enabled = false
          def enabled=(value)
            @enabled = value
          end

          # Accessor method for {#enabled=}.
          def enabled?
            @enabled != false
          end
        end
      end
    end
  end
end