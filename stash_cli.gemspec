# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stash_cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'stash_cli'
  spec.version       = StashCli::VERSION
  spec.authors       = ['Matt Chun-Lum']
  spec.email         = ['mchunlum@mail.com']

  spec.summary       = %q{Manage stash pull requests}
  spec.description   = %q{A tool for managing stash pull requests from the commandline}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'configatron'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'thor'

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
end