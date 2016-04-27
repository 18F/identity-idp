require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Upaya
  class Application < Rails::Application
    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: true,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false,
                       controller_specs: false,
                       request_specs: false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Set the number of seconds the timeout warning should occur before
    # login session is timed out.
    config.session_timeout_warning_seconds = 120
    # Set the number of seconds in which to delay the start of the
    # PeriodicalQuery() call. Make sure the sum of this value and
    # session_timeout_warning_seconds is a multiple of 60 seconds.
    config.session_check_delay             = 60
    # Set the frequency of the PeriodicalQuery() call in seconds.
    # Make sure the sum of this value and session_timeout_warning_seconds
    # is a multiple of 60 seconds.
    config.session_check_frequency         = 60

    # config.middleware.use Rack::Attack unless Figaro.env.pt_mode == 'on'


    # Configure Browserify to use babelify to compile ES6
    config.browserify_rails.commandline_options = '-t [ babelify --presets [ es2015 ] ]'

  end
end
