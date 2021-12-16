# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Fix sassc sometimes segfaulting
Rails.application.config.assets.configure do |env|
  env.export_concurrent = false
end

Sprockets.export_concurrent = Rails.env.test?
