require "timber/context"
require "timber/util"

module Timber
  module Contexts
    # The organization context tracks the organization of the currently
    # authenticated user.
    #
    # You will want to add this context at the time you determine
    # the organization a user belongs to, typically in the authentication
    # flow.
    #
    # Example:
    #
    #   organization_context = Timber::Contexts::Organization.new(id: "abc1234", name: "Timber Inc")
    #   logger.with_context(organization_context) do
    #     # Logging will automatically include this context
    #     logger.info("This is a log message")
    #   end
    #
    class Organization < Context
      @keyspace = :organization

      attr_reader :id, :name

      def initialize(attributes)
        @id = Timber::Util::Object.try(attributes[:id], :to_s)
        @name = attributes[:name]
      end

      # Builds a hash representation containing simple objects, suitable for serialization (JSON).
      def as_json(_options = {})
        {id: id, name: name}
      end
    end
  end
end