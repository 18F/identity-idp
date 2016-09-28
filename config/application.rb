require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# User visible application name. Stored here in a global since it is
# accessed from a wide variety of different places (views, controllers,
# jobs, etc). Please file complaints about use of global variables
# with the appropriate government office.
APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    config.middleware.use Rack::Attack

    # Configure Browserify to use babelify to compile ES6
    config.browserify_rails.commandline_options = '-t [ babelify --presets [ es2015 ] ]'
  end
end
