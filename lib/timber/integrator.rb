module Timber
  # Base class for `Timber::Integrations::*`.
  #
  # @private
  class Integrator
    class RequirementNotMetError < StandardError; end

    class << self
      attr_writer :enabled

      def enabled?
        @enabled != false
      end

      def integrate!(*args)
        if !enabled?
          Config.instance.debug_logger.debug("#{name} integration disabled, skipping") if Config.instance.debug_logger
          return false
        end

        new(*args).integrate!
        Config.instance.debug_logger.debug("Integrated #{name}") if Config.instance.debug_logger
        true
      # RequirementUnsatisfiedError is the only silent failure we support
      rescue RequirementNotMetError => e
        Config.instance.debug_logger.debug("Failed integrating #{name}: #{e.message}") if Config.instance.debug_logger
        false
      end
    end

    def integrate!
      raise NotImplementedError.new
    end
  end
end