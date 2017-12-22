# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../dummy/config/environment', __FILE__)
abort('Rails is running in production mode!') if Rails.env.production?

require 'spec_helper'
require 'rspec/rails'

Rails.backtrace_cleaner.remove_silencers!

require 'simplecov'
SimpleCov.start do
  add_group 'Models', 'app/models'
  add_group 'Libraries', 'lib'

  add_filter '/spec/'
  add_filter '/controllers/'
  add_filter '/scripts/'
  add_filter '/locales/'
  add_filter '/lib/tasks/local_setup_tasks'

  add_filter '/lib/version_history.rb'
  add_filter '/lib/version_history/engine.rb'
  add_filter '/lib/version_history/version.rb'

  track_files "{app,lib}/**/*.rb"
end

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
