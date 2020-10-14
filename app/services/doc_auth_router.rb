# Helps route between various doc auth backends, provided by the identity-doc-auth gem
module DocAuthRouter
  def self.client
    case doc_auth_vendor
    when 'acuant'
      IdentityDocAuth::Acuant::AcuantClient.new(
        assure_id_password: Figaro.env.acuant_assure_id_password,
        assure_id_subscription_id: Figaro.env.acuant_assure_id_subscription_id,
        assure_id_url: Figaro.env.acuant_assure_id_url,
        assure_id_username: Figaro.env.acuant_assure_id_username,
        facial_match_url: Figaro.env.acuant_facial_match_url,
        passlive_url: Figaro.env.acuant_passlive_url,
        timeout: Figaro.env.acuant_timeout,
        friendly_error_message: FriendlyError::Message,
        friendly_error_find_key: FriendlyError::FindKey,
        exception_notifier: method(:notify_exception),
        i18n: I18n,
      )
    when 'lexisnexis'
      IdentityDocAuth::LexisNexis::LexisNexisClient.new(
        account_id: Figaro.env.lexisnexis_account_id,
        base_url: Figaro.env.lexisnexis_base_url,
        request_mode: Figaro.env.lexisnexis_request_mode,
        trueid_account_id: Figaro.env.lexisnexis_trueid_account_id,
        trueid_liveness_workflow: Figaro.env.lexisnexis_trueid_liveness_workflow,
        trueid_noliveness_workflow: Figaro.env.lexisnexis_trueid_noliveness_workflow,
        trueid_password: Figaro.env.lexisnexis_trueid_password,
        trueid_username: Figaro.env.lexisnexis_trueid_username,
        timeout: Figaro.env.lexisnexis_timeout,
        exception_notifier: method(:notify_exception),
        i18n: I18n,
      )
    when 'mock'
      IdentityDocAuth::Mock::DocAuthMockClient.new
    else
      raise "#{doc_auth_vendor} is not a valid doc auth vendor"
    end
  end

  def self.notify_exception(exception, custom_params = nil)
    if custom_params
      NewRelic::Agent.notice_error(exception, custom_params: custom_params)
    else
      NewRelic::Agent.notice_error(exception)
    end
  end

  ##
  # The `acuant_simulator` config is deprecated. The logic to switch vendors
  # based on its value can be removed once FORCE_ACUANT_CONFIG_UPGRADE in
  # acuant_simulator_config_validation.rb has been set to true for at least
  # a deploy cycle.
  #
  def self.doc_auth_vendor
    vendor_from_config = Figaro.env.doc_auth_vendor
    if vendor_from_config.blank?
      return Figaro.env.acuant_simulator == 'true' ? 'mock' : 'acuant'
    end
    vendor_from_config
  end
end
