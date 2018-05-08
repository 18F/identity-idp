Recaptcha.configure do |config|
  config.site_key = Figaro.env.recaptcha_site_key
  config.secret_key = Figaro.env.recaptcha_secret_key
end
