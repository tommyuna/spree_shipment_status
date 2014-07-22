# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_extra_shipment_status'
  s.version     = '2.2.2'
  s.summary     = 'add more detailed shipment status'
  s.description = 'add new column after_shipped_state which contains more specific shipment status \
                   below is each step\
                   1. ready \
                   2. shipped \
                   3. local_delivery_complete \
                   4. overseas_delivery \
                   5. customs \
                   6. domestic_delivery \
                   7. delivered'
  s.required_ruby_version = '>= 1.9.3'

  s.author    = 'Jonghun Yu'
  s.email     = 'jonghun.yu@luuv.it'
  s.homepage  = 'https://github.com/casualsteps/spree_currency_converter'

  #s.files       = `git ls-files`.split("\n")
  #s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '~> 2.2.2'

  s.add_development_dependency 'capybara', '~> 2.1'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl', '~> 4.4'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails',  '~> 2.13'
  s.add_development_dependency 'sass-rails'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
end
