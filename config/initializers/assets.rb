# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w[
  i18n-strings.js email.css ie8.css ie9.css es5-shim.min.js html5shiv.js respond.min.js
  intl-tel-number/intlTelInput.css intl-tel-number/flags.png
  intl-tel-number/flags@2x.png
]

Rails.application.config.assets.precompile += %w[spec_helper.js] if Rails.env.test?
