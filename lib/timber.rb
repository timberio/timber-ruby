# Base (must come first, order matters)
require "timber/version"
require "timber/overrides"
require "timber/config"
require "timber/util"

# Other (sorted alphabetically)
require "timber/contexts"
require "timber/current_context"
require "timber/events"
require "timber/log_devices"
require "timber/log_entry"
require "timber/logger"
require "timber/integrations"
require "timber/timer"

# Load frameworks
require "timber/frameworks"

module Timber
  # Access the main configuration object. Please see {{Timber::Config}} for more details.
  def self.config
    Timber::Config.instance
  end

  # Starts a timer for timing events. Please see {{Timber::Timber.start}} for more details.
  def self.start_timer
    Timber.start
  end

  # Adds context to all logs written within the passed block. Please see
  # {{Timber::CurrentContext.with}} for a more detailed description with examples.
  def self.with_context(context, &block)
    CurrentContext.with(context, &block)
  end
end