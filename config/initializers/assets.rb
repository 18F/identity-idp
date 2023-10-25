# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

require 'extensions/propshaft/asset'

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths.push(
  'node_modules/intl-tel-input/build/img',
  'node_modules/intl-tel-input/build/css',
  'node_modules/@18f/identity-design-system/dist/assets/img',
  'node_modules/@18f/identity-design-system/dist/assets/fonts',
)
