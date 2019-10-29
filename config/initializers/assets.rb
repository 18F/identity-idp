# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w[
  i18n-strings.js email.css es5-shim.min.js html5shiv.js respond.min.js
  intl-tel-input/build/css/intlTelInput.css intl-tel-input/build/img/flags.png
  intl-tel-input/build/img/flags@2x.png
]

Rails.application.config.assets.precompile += %w[spec_helper.js] if Rails.env.test?
