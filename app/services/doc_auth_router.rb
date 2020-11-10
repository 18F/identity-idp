# Helps route between various doc auth backends, provided by the identity-doc-auth gem
module DocAuthRouter
  # Adds translations to responses from Acuant
  class AcuantErrorTranslatorProxy
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def method_missing(name, *args, &block)
      if @client.respond_to?(name)
        translate_form_response!(@client.send(name, *args, &block))
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @client.respond_to?(method_name) || super
    end

    private

    # Translates IdentityDocAuth::GetResultsResponse errors
    def translate_form_response!(response)
      return response unless response.is_a?(IdentityDocAuth::Response)

      translate_friendly_errors!(response)
      translate_generic_errors!(response)

      response
    end

    def translate_friendly_errors!(response)
      response.errors[:results]&.map! do |untranslated_error|
        friendly_message = FriendlyError::Message.call(untranslated_error, 'doc_auth')
        if friendly_message == untranslated_error
          I18n.t('errors.doc_auth.general_error')
        else
          friendly_message
        end
      end&.uniq!
    end

    # rubocop:disable Style/GuardClause
    def translate_generic_errors!(response)
      if response.errors[:network] == true
        response.errors[:network] = I18n.t('errors.doc_auth.acuant_network_error')
      end

      if response.errors[:selfie] == true
        response.errors[:selfie] = I18n.t('errors.doc_auth.selfie')
      end
    end
    # rubocop:enable Style/GuardClause
  end

  class LexisNexisTranslatorProxy
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def method_missing(name, *args, &block)
      if @client.respond_to?(name)
        translate_form_response!(@client.send(name, *args, &block))
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @client.respond_to?(method_name) || super
    end

    private

    # Translates IdentityDocAuth::GetResultsResponse errors
    def translate_form_response!(response)
      return response unless response.is_a?(IdentityDocAuth::Response)

      translate_trueid_errors!(response)
      translate_generic_errors!(response)

      response
    end

    # rubocop:disable Metrics/PerceivedComplexity, Metrics/BlockLength
    def translate_trueid_errors!(response)
      IdentityDocAuth::LexisNexis::ErrorGenerator::ERROR_KEYS.each do |category|
        response.errors[category]&.map! do |plain_error|
          case plain_error
          when IdentityDocAuth::LexisNexis::Errors::BARCODE_CONTENT_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.barcode_content_check')
          when IdentityDocAuth::LexisNexis::Errors::BARCODE_READ_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.barcode_read_check')
          when IdentityDocAuth::LexisNexis::Errors::BIRTH_DATE_CHECKS
            I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')
          when IdentityDocAuth::LexisNexis::Errors::CONTROL_NUMBER_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.control_number_check')
          when IdentityDocAuth::LexisNexis::Errors::DOC_CROSSCHECK
            I18n.t('doc_auth.errors.lexis_nexis.doc_crosscheck')
          when IdentityDocAuth::LexisNexis::Errors::DOC_NUMBER_CHECKS
            I18n.t('doc_auth.errors.lexis_nexis.doc_number_checks')
          when IdentityDocAuth::LexisNexis::Errors::EXPIRATION_CHECKS
            I18n.t('doc_auth.errors.lexis_nexis.expiration_checks')
          when IdentityDocAuth::LexisNexis::Errors::FULL_NAME_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.full_name_check')
          when IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_LIVENESS
            I18n.t('doc_auth.errors.lexis_nexis.general_error_liveness')
          when IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_NO_LIVENESS
            I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
          when IdentityDocAuth::LexisNexis::Errors::ID_NOT_RECOGNIZED
            I18n.t('doc_auth.errors.lexis_nexis.id_not_recognized')
          when IdentityDocAuth::LexisNexis::Errors::ID_NOT_VERIFIED
            I18n.t('doc_auth.errors.lexis_nexis.id_not_verified')
          when IdentityDocAuth::LexisNexis::Errors::ISSUE_DATE_CHECKS
            I18n.t('doc_auth.errors.lexis_nexis.issue_date_checks')
          when IdentityDocAuth::LexisNexis::Errors::MULTIPLE_BACK_ID_FAILURES
            I18n.t('doc_auth.errors.lexis_nexis.multiple_back_id_failures')
          when IdentityDocAuth::LexisNexis::Errors::MULTIPLE_FRONT_ID_FAILURES
            I18n.t('doc_auth.errors.lexis_nexis.multiple_front_id_failures')
          when IdentityDocAuth::LexisNexis::Errors::REF_CONTROL_NUMBER_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.ref_control_number_check')
          when IdentityDocAuth::LexisNexis::Errors::SELFIE_FAILURE
            I18n.t('doc_auth.errors.lexis_nexis.selfie_failure')
          when IdentityDocAuth::LexisNexis::Errors::SEX_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.sex_check')
          when IdentityDocAuth::LexisNexis::Errors::VISIBLE_COLOR_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.visible_color_check')
          when IdentityDocAuth::LexisNexis::Errors::VISIBLE_PHOTO_CHECK
            I18n.t('doc_auth.errors.lexis_nexis.visible_photo_check')
          else
            Rails.logger.warn("unknown LexisNexis error=#{plain_error}")
            I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
          end
        end
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity, Metrics/BlockLength

    # rubocop:disable Style/GuardClause
    def translate_generic_errors!(response)
      if response.errors[:network] == true
        response.errors[:network] = I18n.t('doc_auth.errors.lexis_nexis.network_error')
      end
    end
    # rubocop:enable Style/GuardClause
  end

  def self.client
    case doc_auth_vendor
    when 'acuant'
      AcuantErrorTranslatorProxy.new(
        IdentityDocAuth::Acuant::AcuantClient.new(
          assure_id_password: Figaro.env.acuant_assure_id_password,
          assure_id_subscription_id: Figaro.env.acuant_assure_id_subscription_id,
          assure_id_url: Figaro.env.acuant_assure_id_url,
          assure_id_username: Figaro.env.acuant_assure_id_username,
          facial_match_url: Figaro.env.acuant_facial_match_url,
          passlive_url: Figaro.env.acuant_passlive_url,
          timeout: Figaro.env.acuant_timeout,
          exception_notifier: method(:notify_exception),
        ),
      )
    when 'lexisnexis'
      LexisNexisTranslatorProxy.new(
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
          locale: I18n.locale,
        ),
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

  #
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
