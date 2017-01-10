# Nokogiri 1.7 fails to install on 2.0
if RUBY_VERSION == '2.0.0'
  ENV['NOKOGIRI_VERSION'] = '~> 1.6.8'
end

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)
eval_gemfile File.expand_path('../Gemfile.rails-common', __FILE__)

gem 'rails', '~> 4.2.0'
