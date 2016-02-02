ENV['MONGOID_VERSION'] = 'skip'

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)

gem 'sinatra', '~> 1.4.7'

# To support 1.9.2
gem 'activesupport', '< 4.0.0'
gem 'i18n', '0.6.11'
