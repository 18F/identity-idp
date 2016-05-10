# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:code, :email, :mobile, :password]
# Configure redirect URLs to be filtered based on a matching string.
Rails.application.config.filter_redirect << 'token'
