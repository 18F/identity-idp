# frozen_string_literal: true

BanDisposableEmailValidator.config = IdentityConfig.store.disposable_email_services

MxValidator.config[:timeouts] = [IdentityConfig.store.mx_timeout]
