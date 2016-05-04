eval_gemfile 'gemfiles/Gemfile.base'

gem 'sinatra', '>= 1.2.1'
gem 'grape', '>= 0.10.0'

# These don't play well together
if ENV['ENABLE_PADRINO']
  gem 'padrino', '>= 0.13.0'
else
  gem 'rails', '>= 3.0'
end

group :development do
  gem 'yard'
  gem 'pry'
  gem 'pry-byebug'
end

