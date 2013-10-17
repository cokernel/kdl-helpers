lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = "kdl-helpers"
  spec.version = "0.0.1"
  spec.summary = "KDL-helpers - utilities for KUDL AIPs, DIPs, and such"
  spec.description = "Utilities for KUDL AIPs, DIPs, and such"
  spec.email = "m.slone@gmail.com"
  spec.homepage = "http://github.com/cokernel/kdl-helpers"
  spec.authors = ["Michael Slone"]
  spec.license = "MIT"

  spec.add_dependency 'bagit'
  spec.add_dependency 'exifr'
  spec.add_dependency 'lorax'
  spec.add_dependency 'mustache'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'rails'

  spec.add_development_dependency 'autotest-standalone'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'

  spec.files = `git ls-files`.split($/)
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
end


