# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lemon_way/version'

Gem::Specification.new do |spec|
  spec.name          = "lemon_way"
  spec.version       = LemonWay::VERSION
  spec.authors       = ["Itkin"]
  spec.email         = ["nicolas.papon@webflows.fr"]
  spec.description   = "Describe me"
  spec.summary       = "Describe me"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_development_dependency "pry-rails"
  spec.add_development_dependency "yard"

  spec.add_dependency "activesupport"
  spec.add_dependency "builder"

end
