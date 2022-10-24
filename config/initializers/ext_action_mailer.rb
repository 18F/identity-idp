# Monkeypatches the MessageDelivery to add deliver_now_or_later that
# can route between #deliver_now and #deliver_later
module DeliverLaterArgumentChecker
  def deliver_later(...)
    MailerSensitiveInformationChecker.check_for_sensitive_pii!(@params, @args, @action)
    super(...)
  end
end

module ActionMailer
  class MessageDelivery
    prepend DeliverLaterArgumentChecker

    def deliver_now_or_later(opts = {})
      if IdentityConfig.store.deliver_mail_async
        deliver_later(opts)
      else
        deliver_now
      end
    end
  end
end
