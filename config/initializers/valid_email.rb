config = File.expand_path("#{Rails.root}/config/valid_email.yml", __FILE__)

BanDisposableEmailValidator.config = YAML.load_file(config)['disposable_email_services']
