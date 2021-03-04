Recaptcha.configure do |config|
  config.site_key = Identity::Hostdata.settings.recaptcha_site_key
  config.secret_key = Identity::Hostdata.settings.recaptcha_secret_key
end
