# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "timber/version"

Gem::Specification.new do |s|
  s.name        = "timber"
  s.version     = Timber::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Timber Technologies, Inc."]
  s.email       = ["hi@timber.io"]
  s.homepage    = "http://timber.io"
  s.summary     = "Logs you'll actually use."

  s.required_ruby_version     = '>= 1.9.0'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("msgpack", "~> 1.0")
end
