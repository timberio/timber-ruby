module Timber
  class Config
    # Convenience module for accessing the various `Timber::Integrations::*` classes
    # through the {Timber::Config} object. Timber couples configuration with the class
    # responsibls for implementing it. This provides for a tighter design, but also
    # requires the user to understand and access the various classes. This module aims
    # to provide a simple ruby-like configuration interface for internal Timber classes.
    #
    # For example:
    #
    #     config = Timber::Config.instance
    #     config.integrations.active_record.silence = true
    module Integrations
      extend self
    end
  end
end
