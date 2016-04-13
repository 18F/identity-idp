# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'email_spec'
require 'factory_girl'
require 'shoulda/matchers'
require 'rspec/active_job'

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!

  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include AbstractController::Translation
  config.include Features::LocalizationHelper, type: :feature
  config.include Features::MailerHelper, type: :feature
  config.include Features::SecurityQuestionsHelper, type: :feature
  config.include Features::SessionHelper, type: :feature

  config.before(:suite) do
    Rails.application.load_seed
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    security_question_factories.each { |f| FactoryGirl.create(f.name) }
  end

  config.before(:each) do
    allow(ValidateEmail).to receive(:mx_valid?).and_return(true)
    Rack::Attack.cache.store.clear
  end

  config.after(:all, questions: true) do
    SecurityQuestion.find_each(&:destroy)
    security_question_factories.each { |f| FactoryGirl.create(f.name) }
  end
end

def security_question_factories
  FactoryGirl.factories.select { |f| f.build_class == SecurityQuestion }
end
