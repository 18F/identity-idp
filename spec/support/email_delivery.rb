module ActionMailer
  class MessageDelivery
    def deliver_later(_opts = {})
      # rubocop:disable IdentityIdp/MailLaterLinter
      MailerSensitiveInformationChecker.check_for_sensitive_pii!(@args, @action)
      deliver_now
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end
end
