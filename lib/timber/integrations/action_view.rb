require "timber/integration"
require "timber/integrations/action_view/log_subscriber"

module Timber
  module Integrations
    # Module for holding *all* ActionView integrations. See {Integration} for
    # configuration details for all integrations.
    module ActionView
      extend Integration

      def self.integrate!
        LogSubscriber.integrate!
      end
    end
  end
end