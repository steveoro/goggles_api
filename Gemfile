# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.7.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '>= 6.0.6', '< 6.1.0'
gem 'rails-i18n', '~> 6.0'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.4.4'
# Use Puma as the app server
gem 'puma', '>= 5.3.1'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.7'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'

gem 'api-pagination'
gem 'devise'
gem 'goggles_db', git: 'https://github.com/steveoro/goggles_db'
gem 'grape'
gem 'grape_logging'
gem 'grape-route-helpers'
gem 'kaminari'
gem 'rest-client'
gem 'scenic'
gem 'scenic-mysql_adapter'
gem 'simple_command'

# Inherited data factories from DB engine, published also on production/staging
# to allow fixture creation for testing purposes when using production structure dumps:
gem 'factory_bot_rails'
gem 'ffaker'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'guard'
  gem 'guard-brakeman'
  gem 'guard-bundler', require: false
  gem 'guard-haml_lint'
  gem 'guard-inch'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'guard-spring'
  gem 'haml_lint', require: false
  gem 'inch', require: false # grades source documentation
  gem 'listen', '~> 3.2'
  # [20210128] Rubocop 1.9.0 seems to have several issues with the current stack
  gem 'rubocop' # '= 1.8.1', require: false
  gem 'rubocop-performance'
  gem 'rubocop-rails', require: false
  gem 'rubocop-rake'
  gem 'rubocop-rspec'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'spring-commands-rubocop'
  gem 'spring-watcher-listen'
end

group :development, :test do
  gem 'awesome_print' # color output formatter for Ruby objects
  gem 'brakeman'
  gem 'bullet'
  # gem 'byebug' # Uncomment and call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'letter_opener'
  gem 'pry'
  gem 'rspec'
  gem 'rspec_pacman_formatter'
  gem 'rspec-rails'
end

group :test do
  # For CodeClimate: use the stand-alone 'cc-test-reporter' from the command line.
  gem 'codecov', require: false
  gem 'n_plus_one_control'
  # n_plus_one_control adds a DSL to check for "N+1 queries" directly in test environment.
  # (Bullet works best just on development). Do not use memoized values for testing.
  # Example:
  #          expect { get :index }.to perform_constant_number_of_queries"
  gem 'rspec_junit_formatter' # required by new Semaphore test reports
  gem 'simplecov', '= 0.13.0', require: false
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
