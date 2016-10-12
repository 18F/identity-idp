require 'feature_management'
if FeatureManagement.enable_i18n_mode?
  # load libraries or overrides to be enabled with i18n_mode:
  require File.join(Rails.root, 'lib', 'i18n_override.rb')
end
