class MailerSensitiveInformationChecker
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
    include ::NewRelic::Agent::MethodTracer
    add_method_tracer :check_for_sensitive_pii!, "Custom/#{name}/check_for_sensitive_pii!"
  end
end
