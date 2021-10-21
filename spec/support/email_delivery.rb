module ActionMailer
  class MessageDelivery
    def deliver_later
      # rubocop:disable IdentityIdp/MailLaterLinter
      deliver_now
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end
end
