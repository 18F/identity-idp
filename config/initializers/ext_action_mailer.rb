# Monkeypatches the MessageDelivery to add deliver_now_or_later that
# can route between #deliver_now and #deliver_later
module ActionMailer
  class MessageDelivery
    alias_method :original_deliver_later, :deliver_later
    def deliver_now_or_later(opts = {})
      MailerSensitiveInformationChecker.check_for_sensitive_pii!(@args, @action)
      # rubocop:disable IdentityIdp/MailLaterLinter
      if IdentityConfig.store.deliver_mail_async
        original_deliver_later(opts)
      else
        deliver_now
      end
      # rubocop:enable IdentityIdp/MailLaterLinter
    end

    def deliver_later(opts = {})
      MailerSensitiveInformationChecker.check_for_sensitive_pii!(@args, @action)
      original_deliver_later(opts)
    end
  end
end

class MailerSensitiveInformationChecker
  def self.check_for_sensitive_pii!(args_array, action)
    args = ActiveJob::Arguments.serialize(args_array)
    serialized_args_string = args.to_s

    args.each do |arg|
      next unless args.is_a?(Hash)

      arg.deep_transform_keys do |key|
        if SessionEncryptor::SENSITIVE_KEYS.include?(key.to_s)
          exception = SessionEncryptor::SensitiveKeyError.new(
            "#{key} unexpectedly appeared in #{action} Mailer args",
          )
          self.alert(exception)
        end
      end
    end

    if SessionEncryptor::SENSITIVE_REGEX.match?(serialized_args_string)
      self.alert(SessionEncryptor::SensitiveValueError.new)
    end
  end

  def self.alert(exception)
    if IdentityConfig.store.session_encryptor_alert_enabled
      NewRelic::Agent.notice_error(exception)
    else
      raise exception
    end
  end
end
