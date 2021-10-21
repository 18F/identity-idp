module ActionMailer
  class MessageDelivery
    def deliver_later
      # rubobop:disable IdentityIdp/MailLaterLinter
      deliver_now
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end
end
