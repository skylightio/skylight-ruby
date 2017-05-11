ENV['MONGOID_VERSION'] = 'skip'

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)

gem 'sinatra', '~> 1.3.6'
gem 'sinatra-contrib'

# To support 1.9.2
gem 'activesupport', '< 4.0.0'
gem 'i18n', '0.6.11'
