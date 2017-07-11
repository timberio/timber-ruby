require "timber/context"
require "timber/util"

module Timber
  module Contexts
    # The user context adds data about the currently authenticated user to your logs.
    # By adding this context all of your logs will contain user information. This allows
    # filter and tail logs by specific users.
    #
    # @note This is tracked automatically with the {Integrations::Rack::UserContext} rack
    #   middleware and it can be configured for custom integrations.
    #   See {Integrations::Rack::UserContext} for more details.
    class User < Context
      @keyspace = :user

      attr_reader :id, :name, :email

      def initialize(attributes)
        @id = attributes[:id]
        @name = attributes[:name]
        @email = attributes[:email]
      end

      # Builds a hash representation containing simple objects, suitable for serialization (JSON).
      def as_json(_options = {})
        {id: Timber::Util::Object.try(id, :to_s), name: name, email: email}
      end
    end
  end
end