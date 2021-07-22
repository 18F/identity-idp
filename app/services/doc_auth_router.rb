# Helps route between various doc auth backends, provided by the identity-doc-auth gem
module DocAuthRouter
  ERROR_TRANSLATIONS = {
    # i18n-tasks-use t('doc_auth.errors.alerts.barcode_content_check')
    IdentityDocAuth::Errors::BARCODE_CONTENT_CHECK =>
      'doc_auth.errors.alerts.barcode_content_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.barcode_read_check')
    IdentityDocAuth::Errors::BARCODE_READ_CHECK =>
      'doc_auth.errors.alerts.barcode_read_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.birth_date_checks')
    IdentityDocAuth::Errors::BIRTH_DATE_CHECKS =>
      'doc_auth.errors.alerts.birth_date_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.control_number_check')
    IdentityDocAuth::Errors::CONTROL_NUMBER_CHECK =>
      'doc_auth.errors.alerts.control_number_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_crosscheck')
    IdentityDocAuth::Errors::DOC_CROSSCHECK =>
      'doc_auth.errors.alerts.doc_crosscheck',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_number_checks')
    IdentityDocAuth::Errors::DOC_NUMBER_CHECKS =>
      'doc_auth.errors.alerts.doc_number_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.expiration_checks')
    IdentityDocAuth::Errors::DOCUMENT_EXPIRED_CHECK =>
      'doc_auth.errors.alerts.expiration_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.expiration_checks')
    IdentityDocAuth::Errors::EXPIRATION_CHECKS =>
      'doc_auth.errors.alerts.expiration_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.full_name_check')
    IdentityDocAuth::Errors::FULL_NAME_CHECK =>
      'doc_auth.errors.alerts.full_name_check',
    # i18n-tasks-use t('doc_auth.errors.general.liveness')
    IdentityDocAuth::Errors::GENERAL_ERROR_LIVENESS =>
      'doc_auth.errors.general.liveness',
    # i18n-tasks-use t('doc_auth.errors.general.no_liveness')
    IdentityDocAuth::Errors::GENERAL_ERROR_NO_LIVENESS =>
      'doc_auth.errors.general.no_liveness',
    # i18n-tasks-use t('doc_auth.errors.alerts.id_not_recognized')
    IdentityDocAuth::Errors::ID_NOT_RECOGNIZED =>
      'doc_auth.errors.alerts.id_not_recognized',
    # i18n-tasks-use t('doc_auth.errors.alerts.id_not_verified')
    IdentityDocAuth::Errors::ID_NOT_VERIFIED =>
      'doc_auth.errors.alerts.id_not_verified',
    # i18n-tasks-use t('doc_auth.errors.alerts.issue_date_checks')
    IdentityDocAuth::Errors::ISSUE_DATE_CHECKS =>
      'doc_auth.errors.alerts.issue_date_checks',
    # i18n-tasks-use t('doc_auth.errors.general.multiple_back_id_failures')
    IdentityDocAuth::Errors::MULTIPLE_BACK_ID_FAILURES =>
      'doc_auth.errors.general.multiple_back_id_failures',
    # i18n-tasks-use t('doc_auth.errors.general.multiple_front_id_failures')
    IdentityDocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES =>
      'doc_auth.errors.general.multiple_front_id_failures',
    # i18n-tasks-use t('doc_auth.errors.alerts.ref_control_number_check')
    IdentityDocAuth::Errors::REF_CONTROL_NUMBER_CHECK =>
      'doc_auth.errors.alerts.ref_control_number_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.selfie_failure')
    IdentityDocAuth::Errors::SELFIE_FAILURE => 'doc_auth.errors.alerts.selfie_failure',
    # i18n-tasks-use t('doc_auth.errors.alerts.sex_check')
    IdentityDocAuth::Errors::SEX_CHECK => 'doc_auth.errors.alerts.sex_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.visible_color_check')
    IdentityDocAuth::Errors::VISIBLE_COLOR_CHECK => 'doc_auth.errors.alerts.visible_color_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.visible_photo_check')
    IdentityDocAuth::Errors::VISIBLE_PHOTO_CHECK => 'doc_auth.errors.alerts.visible_photo_check',
    # i18n-tasks-use t('doc_auth.errors.dpi.top_msg')
    IdentityDocAuth::Errors::DPI_LOW_ONE_SIDE => 'doc_auth.errors.dpi.top_msg',
    # i18n-tasks-use t('doc_auth.errors.dpi.top_msg_plural')
    IdentityDocAuth::Errors::DPI_LOW_BOTH_SIDES => 'doc_auth.errors.dpi.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.sharpness.top_msg')
    IdentityDocAuth::Errors::SHARP_LOW_ONE_SIDE => 'doc_auth.errors.sharpness.top_msg',
    # i18n-tasks-use t('doc_auth.errors.sharpness.top_msg_plural')
    IdentityDocAuth::Errors::SHARP_LOW_BOTH_SIDES => 'doc_auth.errors.sharpness.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.glare.top_msg')
    IdentityDocAuth::Errors::GLARE_LOW_ONE_SIDE => 'doc_auth.errors.glare.top_msg',
    # i18n-tasks-use t('doc_auth.errors.glare.top_msg_plural')
    IdentityDocAuth::Errors::GLARE_LOW_BOTH_SIDES => 'doc_auth.errors.glare.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.http.image_load')
    IdentityDocAuth::Errors::IMAGE_LOAD_FAILURE => 'doc_auth.errors.http.image_load',
    # i18n-tasks-use t('doc_auth.errors.http.pixel_depth')
    IdentityDocAuth::Errors::PIXEL_DEPTH_FAILURE => 'doc_auth.errors.http.pixel_depth',
    # i18n-tasks-use t('doc_auth.errors.http.image_size')
    IdentityDocAuth::Errors::IMAGE_SIZE_FAILURE => 'doc_auth.errors.http.image_size',
  }.freeze

  class DocAuthErrorTranslatorProxy
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

    def translate_form_response!(response)
      return response unless response.is_a?(IdentityDocAuth::Response)

      # This needs to happen before we translate, since it relies on the original error keys
      response = ExpiredLicenseAllower.new(response).processed_response

      translate_doc_auth_errors!(response)
      translate_generic_errors!(response)

      response
    end

    def translate_doc_auth_errors!(response)
      # acuant selfie errors are handled in translate_generic_errors!
      error_keys = IdentityDocAuth::ErrorGenerator::ERROR_KEYS.dup
      error_keys.delete(:selfie) if DocAuthRouter.doc_auth_vendor == 'acuant'

      error_keys.each do |category|
        response.errors[category]&.map! do |plain_error|
          error_key = ERROR_TRANSLATIONS[plain_error]
          if error_key
            I18n.t(error_key)
          else
            Rails.logger.warn("unknown DocAuth error=#{plain_error}")
            # This isn't right, this should depend on the liveness setting
            I18n.t('doc_auth.errors.general.no_liveness')
          end
        end
      end
    end

    def translate_generic_errors!(response)
      if response.errors[:network] == true
        response.errors[:network] = I18n.t('doc_auth.errors.general.network_error')
      end

      # this is only relevant to acuant code path
      if response.errors[:selfie] == true
        response.errors[:selfie] = I18n.t('doc_auth.errors.general.liveness')
      end
    end
  end

  def self.client
    case doc_auth_vendor
    when 'acuant'
      DocAuthErrorTranslatorProxy.new(
        IdentityDocAuth::Acuant::AcuantClient.new(
          assure_id_password: IdentityConfig.store.acuant_assure_id_password,
          assure_id_subscription_id: IdentityConfig.store.acuant_assure_id_subscription_id,
          assure_id_url: IdentityConfig.store.acuant_assure_id_url,
          assure_id_username: IdentityConfig.store.acuant_assure_id_username,
          facial_match_url: IdentityConfig.store.acuant_facial_match_url,
          passlive_url: IdentityConfig.store.acuant_passlive_url,
          timeout: IdentityConfig.store.acuant_timeout,
          exception_notifier: method(:notify_exception),
          dpi_threshold: IdentityConfig.store.doc_auth_error_dpi_threshold,
          sharpness_threshold: IdentityConfig.store.doc_auth_error_sharpness_threshold,
          glare_threshold: IdentityConfig.store.doc_auth_error_glare_threshold,
        ),
      )
    when 'lexisnexis'
      DocAuthErrorTranslatorProxy.new(
        IdentityDocAuth::LexisNexis::LexisNexisClient.new(
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
          trueid_account_id: IdentityConfig.store.lexisnexis_trueid_account_id,
          trueid_liveness_workflow: IdentityConfig.store.lexisnexis_trueid_liveness_workflow,
          trueid_noliveness_workflow: IdentityConfig.store.lexisnexis_trueid_noliveness_workflow,
          trueid_password: IdentityConfig.store.lexisnexis_trueid_password,
          trueid_username: IdentityConfig.store.lexisnexis_trueid_username,
          timeout: IdentityConfig.store.lexisnexis_timeout,
          exception_notifier: method(:notify_exception),
          locale: I18n.locale,
          dpi_threshold: IdentityConfig.store.doc_auth_error_dpi_threshold,
          sharpness_threshold: IdentityConfig.store.doc_auth_error_sharpness_threshold,
          glare_threshold: IdentityConfig.store.doc_auth_error_glare_threshold,
        ),
      )
    when 'mock'
      DocAuthErrorTranslatorProxy.new(IdentityDocAuth::Mock::DocAuthMockClient.new)
    else
      raise "#{doc_auth_vendor} is not a valid doc auth vendor"
    end
  end

  def self.notify_exception(exception, custom_params = nil, expected = false)
    if custom_params
      NewRelic::Agent.notice_error(exception, custom_params: custom_params, expected: expected)
    else
      NewRelic::Agent.notice_error(exception, expected: expected)
    end
  end

  def self.doc_auth_vendor
    IdentityConfig.store.doc_auth_vendor
  end
end
