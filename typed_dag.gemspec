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
  s.description = 'Allows rails models to work as the edges and nodes of a
                   directed acyclic graph (dag). The edges may be typed.'
  s.homepage    = 'https://github.com/opf/typed_dag'
  s.license     = 'MIT'

  s.files = Dir['{lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  s.add_dependency 'rails', '>= 5.0.4'

  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'mysql2'
end
