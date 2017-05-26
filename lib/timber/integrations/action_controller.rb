require "timber/integration"
require "timber/integrations/action_controller/log_subscriber"

module Timber
  module Integrations
    # Module for holding *all* ActionController integrations. See {Integration} for
    # configuration details for all integrations.
    module ActionController
      extend Integration

      def self.integrate!
        LogSubscriber.integrate!
      end
    end
  end
end