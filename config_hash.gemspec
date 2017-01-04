Gem::Specification.new do |s|
  s.name = 'config_hash'
  s.version = '1.1.5'
  s.summary = 'a hash built for configurations.'
  s.description = 'A safe hash that can process values and use dot notation.'
  s.authors = ['Zach Lome']
  s.email = ['zslome@gmail.com']
  s.homepage = 'https://github.com/kuraiou/config_hash'
  s.license = 'MIT'

  s.files = ['lib/config_hash.rb', 'lib/config_hash/processors.rb']
  s.require_path = 'lib'

  s.add_development_dependency 'bundler', '~> 1.11'
  s.add_development_dependency 'rspec', '~> 3.4'
end
