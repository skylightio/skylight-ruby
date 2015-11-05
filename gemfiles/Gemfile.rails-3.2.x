ENV['MONGOID_VERSION'] = 'skip'

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)
eval_gemfile File.expand_path('../Gemfile.rails-common', __FILE__)

gem 'rails', '~> 3.2.0'
gem 'rack-cache', '1.2' # 1.3 requires Ruby 2
gem 'i18n', '0.6.11'

# 0.9 tries to load ActiveSupport::TestCase which requires test-unit
if !ENV['SKIP_EXTERNAL'] && (!ENV['AMS_VERSION'] || ENV['AMS_VERSION'] =~ /0.9/)
  gem 'test-unit'
end
