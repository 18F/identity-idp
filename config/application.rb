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
    config.active_job.queue_adapter = :sidekiq

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    config.autoload_paths << Rails.root.join('app/mailers/concerns')

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    config.middleware.insert_before 0, 'Rack::Cors' do
      allow do
        origins '*'

        resource '/api/deploy*',
                 headers: :any,
                 methods: [:get, :options]
      end
    end

    config.middleware.use Rack::Attack

    # Configure Browserify to use babelify to compile ES6
    config.browserify_rails.commandline_options = '-t [ babelify --presets [ es2015 ] ]'

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
  end
end
