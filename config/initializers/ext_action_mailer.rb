# Monkeypatches the MessageDelivery to add deliver_now_or_later that
# can route between #deliver_now and #deliver_later
module ActionMailer
  class MessageDelivery
    def deliver_now_or_later(opts = {})
      # rubocop:disable IdentityIdp/MailLaterLinter
      if IdentityConfig.store.deliver_mail_async
        deliver_later(opts)
      else
        deliver_now
      end
      # rubocop:enable IdentityIdp/MailLaterLinter
    end
  end
end
