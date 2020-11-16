Recaptcha.configure do |config|
  config.site_key = AppConfig.env.recaptcha_site_key
  config.secret_key = AppConfig.env.recaptcha_secret_key
end
