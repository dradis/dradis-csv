$:.push File.expand_path('../lib', __FILE__)
require 'dradis/plugins/csv/version'
version = Dradis::Plugins::CSV::VERSION::STRING

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.platform    = Gem::Platform::RUBY
  spec.name        = 'dradis-csv'
  spec.version     = version
  spec.summary     = 'CSV add-on for the Dradis Framework.'
  spec.description = 'This add-on allows you to upload and parse CSV output into Dradis.'

  spec.license     = 'GPL-2'

  spec.authors     = ['Daniel Martin']
  spec.email       = ['etd@nomejortu.com']
  spec.homepage    = 'http://dradisframework.org'

  spec.files       = `git ls-files`.split("\n")
  spec.executables = spec.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  spec.test_files  = spec.files.grep(%r{^(spec|features)/})

  spec.add_dependency 'dradis-plugins', '~> 4.0'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
