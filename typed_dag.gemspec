$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'typed_dag/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'typed_dag'
  s.version     = TypedDag::VERSION
  s.authors     = ['OpenProject GmbH']
  s.email       = ['info@openproject.com']
  s.summary     = 'Directed acyclic graphs for rails model with typed edges.'
  s.description = 'Allows rails models to work as the edges and nodes of a \
                   directed acyclic graph (dag). The edges may be typed.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '>= 5.0.4'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'factory_girl_rails'

  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'pg'
end
