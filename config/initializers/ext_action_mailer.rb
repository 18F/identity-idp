# Monkeypatches the MessageDelivery to add deliver_now_or_later that
# can route between #deliver_now and #deliver_later
module ActionMailer
  class MessageDelivery
    alias_method :original_deliver_later, :deliver_later
    def deliver_now_or_later(opts = {})
      MailerSensitiveInformationChecker.check_for_sensitive_pii!(@params, @args, @action)
      # rubocop:disable IdentityIdp/MailLaterLinter
      if IdentityConfig.store.deliver_mail_async
        deliver_later(opts)
      else
        deliver_now
      end
      # rubocop:enable IdentityIdp/MailLaterLinter
    end

    def deliver_later(opts = {})
      MailerSensitiveInformationChecker.check_for_sensitive_pii!(@params, @args, @action)
      original_deliver_later(opts)
    end
  end
end
