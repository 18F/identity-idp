config = Rails.root.join('config', 'valid_email.yml')

BanDisposableEmailValidator.config = YAML.load_file(config)['disposable_email_services']

MxValidator.config[:timeouts] = [IdentityConfig.store.mx_timeout]
