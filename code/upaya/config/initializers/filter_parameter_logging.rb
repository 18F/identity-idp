# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password, :security_answers_attributes, :mobile, :second_factor_ids]
# Configure redirect URLs to be filtered based on a matching string.
Rails.application.config.filter_redirect << 'token'
