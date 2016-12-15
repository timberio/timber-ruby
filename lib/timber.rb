# core classes
require "json" # brings to_json to the core classes
require "msgpack" # brings to_msgpack to the core classes

# Base (must come first, order matters)
require "timber/config"
require "timber/context"
require "timber/event"
require "timber/probe"
require "timber/util"
require "timber/version"

# Other (sorted alphabetically)
require "timber/contexts"
require "timber/current_context"
require "timber/events"
require "timber/log_devices"
require "timber/log_entry"
require "timber/logger"
require "timber/probes"

# Load frameworks
require "timber/frameworks"