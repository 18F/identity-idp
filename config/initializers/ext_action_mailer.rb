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

class MailerSensitiveInformationChecker
  include ::NewRelic::Agent::MethodTracer
  class SensitiveKeyError < StandardError; end

  class SensitiveValueError < StandardError; end

  def self.check_for_sensitive_pii!(params, args_array, action)
    args = ActiveJob::Arguments.serialize(args_array)
    serialized_params = ActiveJob::Arguments.serialize(params)
    serialized_args_string = args.to_s
    serialized_params_string = serialized_params.to_s

    if params[:email_address].is_a?(EmailAddress)
      check_hash(params.except(:email_address), action)
    else
      check_hash(params, action)
    end
    args.each do |arg|
      next unless arg.is_a?(Hash)
      check_hash(arg, action)
    end

    if SessionEncryptor::SENSITIVE_REGEX.match?(serialized_args_string)
      self.alert(SensitiveValueError.new)
    end

    if SessionEncryptor::SENSITIVE_REGEX.match?(serialized_params_string)
      self.alert(SensitiveValueError.new)
    end
  end

  def self.check_hash(hash, action)
    hash.deep_transform_keys do |key|
      if SessionEncryptor::SENSITIVE_KEYS.include?(key.to_s)
        exception = SensitiveKeyError.new(
          "#{key} unexpectedly appeared in #{action} Mailer args",
        )
        self.alert(exception)
      end
    end
  end

  def self.alert(exception)
    if IdentityConfig.store.session_encryptor_alert_enabled
      NewRelic::Agent.notice_error(exception)
    else
      raise exception
    end
  end

  class << self
    add_method_tracer :check_for_sensitive_pii!, "Custom/#{name}/check_for_sensitive_pii!"
  end
end
