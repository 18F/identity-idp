# Helps route between various doc auth backends
module DocAuthRouter
  ERROR_TRANSLATIONS = {
    # i18n-tasks-use t('doc_auth.errors.alerts.barcode_content_check')
    DocAuth::Errors::BARCODE_CONTENT_CHECK =>
      'doc_auth.errors.alerts.barcode_content_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.barcode_read_check')
    DocAuth::Errors::BARCODE_READ_CHECK =>
      'doc_auth.errors.alerts.barcode_read_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.birth_date_checks')
    DocAuth::Errors::BIRTH_DATE_CHECKS =>
      'doc_auth.errors.alerts.birth_date_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.control_number_check')
    DocAuth::Errors::CONTROL_NUMBER_CHECK =>
      'doc_auth.errors.alerts.control_number_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_crosscheck')
    DocAuth::Errors::DOC_CROSSCHECK =>
      'doc_auth.errors.alerts.doc_crosscheck',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_number_checks')
    DocAuth::Errors::DOC_NUMBER_CHECKS =>
      'doc_auth.errors.alerts.doc_number_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.expiration_checks')
    DocAuth::Errors::DOCUMENT_EXPIRED_CHECK =>
      'doc_auth.errors.alerts.expiration_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.expiration_checks')
    DocAuth::Errors::EXPIRATION_CHECKS =>
      'doc_auth.errors.alerts.expiration_checks',
    # i18n-tasks-use t('doc_auth.errors.alerts.full_name_check')
    DocAuth::Errors::FULL_NAME_CHECK =>
      'doc_auth.errors.alerts.full_name_check',
    # i18n-tasks-use t('doc_auth.errors.general.no_liveness')
    DocAuth::Errors::GENERAL_ERROR =>
      'doc_auth.errors.general.no_liveness',
    # i18n-tasks-use t('doc_auth.errors.alerts.id_not_recognized')
    DocAuth::Errors::ID_NOT_RECOGNIZED =>
      'doc_auth.errors.alerts.id_not_recognized',
    # i18n-tasks-use t('doc_auth.errors.alerts.id_not_verified')
    DocAuth::Errors::ID_NOT_VERIFIED =>
      'doc_auth.errors.alerts.id_not_verified',
    # i18n-tasks-use t('doc_auth.errors.alerts.issue_date_checks')
    DocAuth::Errors::ISSUE_DATE_CHECKS =>
      'doc_auth.errors.alerts.issue_date_checks',
    # i18n-tasks-use t('doc_auth.errors.general.multiple_back_id_failures')
    DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES =>
      'doc_auth.errors.general.multiple_back_id_failures',
    # i18n-tasks-use t('doc_auth.errors.general.multiple_front_id_failures')
    DocAuth::Errors::MULTIPLE_FRONT_ID_FAILURES =>
      'doc_auth.errors.general.multiple_front_id_failures',
    # i18n-tasks-use t('doc_auth.errors.alerts.ref_control_number_check')
    DocAuth::Errors::REF_CONTROL_NUMBER_CHECK =>
      'doc_auth.errors.alerts.ref_control_number_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.selfie_failure')
    DocAuth::Errors::SELFIE_FAILURE => 'doc_auth.errors.alerts.selfie_failure',
    # i18n-tasks-use t('doc_auth.errors.alerts.sex_check')
    DocAuth::Errors::SEX_CHECK => 'doc_auth.errors.alerts.sex_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.visible_color_check')
    DocAuth::Errors::VISIBLE_COLOR_CHECK => 'doc_auth.errors.alerts.visible_color_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.visible_photo_check')
    DocAuth::Errors::VISIBLE_PHOTO_CHECK => 'doc_auth.errors.alerts.visible_photo_check',
    # i18n-tasks-use t('doc_auth.errors.dpi.top_msg')
    DocAuth::Errors::DPI_LOW_ONE_SIDE => 'doc_auth.errors.dpi.top_msg',
    # i18n-tasks-use t('doc_auth.errors.dpi.top_msg_plural')
    DocAuth::Errors::DPI_LOW_BOTH_SIDES => 'doc_auth.errors.dpi.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.dpi.failed_short')
    DocAuth::Errors::DPI_LOW_FIELD => 'doc_auth.errors.dpi.failed_short',
    # i18n-tasks-use t('doc_auth.errors.sharpness.top_msg')
    DocAuth::Errors::SHARP_LOW_ONE_SIDE => 'doc_auth.errors.sharpness.top_msg',
    # i18n-tasks-use t('doc_auth.errors.sharpness.top_msg_plural')
    DocAuth::Errors::SHARP_LOW_BOTH_SIDES => 'doc_auth.errors.sharpness.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.sharpness.failed_short')
    DocAuth::Errors::SHARP_LOW_FIELD => 'doc_auth.errors.sharpness.failed_short',
    # i18n-tasks-use t('doc_auth.errors.glare.top_msg')
    DocAuth::Errors::GLARE_LOW_ONE_SIDE => 'doc_auth.errors.glare.top_msg',
    # i18n-tasks-use t('doc_auth.errors.glare.top_msg_plural')
    DocAuth::Errors::GLARE_LOW_BOTH_SIDES => 'doc_auth.errors.glare.top_msg_plural',
    # i18n-tasks-use t('doc_auth.errors.glare.failed_short')
    DocAuth::Errors::GLARE_LOW_FIELD => 'doc_auth.errors.glare.failed_short',
    # i18n-tasks-use t('doc_auth.errors.http.image_load')
    DocAuth::Errors::IMAGE_LOAD_FAILURE => 'doc_auth.errors.http.image_load',
    # i18n-tasks-use t('doc_auth.errors.http.pixel_depth')
    DocAuth::Errors::PIXEL_DEPTH_FAILURE => 'doc_auth.errors.http.pixel_depth',
    # i18n-tasks-use t('doc_auth.errors.http.image_size')
    DocAuth::Errors::IMAGE_SIZE_FAILURE => 'doc_auth.errors.http.image_size',
    # i18n-tasks-use t('doc_auth.errors.general.fallback_field_level')
    DocAuth::Errors::FALLBACK_FIELD_LEVEL => 'doc_auth.errors.general.fallback_field_level',
  }.freeze

  class DocAuthErrorTranslatorProxy
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def method_missing(name, ...)
      if @client.respond_to?(name)
        translate_form_response!(@client.send(name, ...))
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @client.respond_to?(method_name) || super
    end

    private

    def translate_form_response!(response)
      return response unless response.is_a?(DocAuth::Response)

      translate_doc_auth_errors!(response)
      translate_generic_errors!(response)

      response
    end

    def translate_doc_auth_errors!(response)
      # acuant selfie errors are handled in translate_generic_errors!
      error_keys = DocAuth::ErrorGenerator::ERROR_KEYS.dup
      error_keys.delete(:selfie) if @client.is_a?(DocAuth::Acuant::AcuantClient)

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

  # rubocop:disable Layout/LineLength
  # @param [Proc,nil] warn_notifier proc takes a hash, and should log that hash to events.log
  def self.client(vendor_discriminator: nil, warn_notifier: nil, analytics: nil)
    case doc_auth_vendor(discriminator: vendor_discriminator, analytics: analytics)
    when Idp::Constants::Vendors::ACUANT
      DocAuthErrorTranslatorProxy.new(
        DocAuth::Acuant::AcuantClient.new(
          assure_id_password: IdentityConfig.store.acuant_assure_id_password,
          assure_id_subscription_id: IdentityConfig.store.acuant_assure_id_subscription_id,
          assure_id_url: IdentityConfig.store.acuant_assure_id_url,
          assure_id_username: IdentityConfig.store.acuant_assure_id_username,
          facial_match_url: IdentityConfig.store.acuant_facial_match_url,
          passlive_url: IdentityConfig.store.acuant_passlive_url,
          warn_notifier: warn_notifier,
          dpi_threshold: IdentityConfig.store.doc_auth_error_dpi_threshold,
          sharpness_threshold: IdentityConfig.store.doc_auth_error_sharpness_threshold,
          glare_threshold: IdentityConfig.store.doc_auth_error_glare_threshold,
        ),
      )
    when Idp::Constants::Vendors::LEXIS_NEXIS, 'lexisnexis' # Use constant once configured in prod
      DocAuthErrorTranslatorProxy.new(
        DocAuth::LexisNexis::LexisNexisClient.new(
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
          trueid_account_id: IdentityConfig.store.lexisnexis_trueid_account_id,
          trueid_noliveness_cropping_workflow: IdentityConfig.store.lexisnexis_trueid_noliveness_cropping_workflow,
          trueid_noliveness_nocropping_workflow: IdentityConfig.store.lexisnexis_trueid_noliveness_nocropping_workflow,
          trueid_password: IdentityConfig.store.lexisnexis_trueid_password,
          trueid_username: IdentityConfig.store.lexisnexis_trueid_username,
          warn_notifier: warn_notifier,
          locale: I18n.locale,
          dpi_threshold: IdentityConfig.store.doc_auth_error_dpi_threshold,
          sharpness_threshold: IdentityConfig.store.doc_auth_error_sharpness_threshold,
          glare_threshold: IdentityConfig.store.doc_auth_error_glare_threshold,
        ),
      )
    when Idp::Constants::Vendors::MOCK
      DocAuthErrorTranslatorProxy.new(
        DocAuth::Mock::DocAuthMockClient.new(
          warn_notifier: warn_notifier,
        ),
      )
    else
      raise "#{doc_auth_vendor(discriminator: vendor_discriminator)} is not a valid doc auth vendor"
    end
  end
  # rubocop:enable Layout/LineLength

  def self.doc_auth_vendor(discriminator: nil, analytics: nil)
    case AbTests::DOC_AUTH_VENDOR.bucket(discriminator)
    when :alternate_vendor
      IdentityConfig.store.doc_auth_vendor_randomize_alternate_vendor
    else
      analytics&.idv_doc_auth_randomizer_defaulted if discriminator.blank?

      IdentityConfig.store.doc_auth_vendor
    end
  end
end
