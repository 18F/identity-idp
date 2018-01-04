# Be sure to restart your server when you modify this file.
SAFE_KEYS = %w[
  action
  address_delivery_method
  button
  commit
  controller
  otp_delivery_preference
  reauthn
  timeout
  otp_delivery_selection_form
  utf8
].freeze

SANITIZED_VALUE = '[FILTERED]'.freeze

Rails.application.config.filter_parameters << lambda do |key, value|
  if value.respond_to?(:replace)
    value.replace(SANITIZED_VALUE) unless SAFE_KEYS.include?(key)
  end
end

# Configure redirect URLs to be filtered based on a matching string.
Rails.application.config.filter_redirect << 'token'
