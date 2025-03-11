# frozen_string_literal: true

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
    DocAuth::Errors::CARD_TYPE =>
      'doc_auth.errors.card_type',
    # i18n-tasks-use t('doc_auth.errors.alerts.control_number_check')
    DocAuth::Errors::CONTROL_NUMBER_CHECK =>
      'doc_auth.errors.alerts.control_number_check',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_crosscheck')
    DocAuth::Errors::DOC_CROSSCHECK =>
      'doc_auth.errors.alerts.doc_crosscheck',
    # i18n-tasks-use t('doc_auth.errors.alerts.doc_number_checks')
    DocAuth::Errors::DOC_NUMBER_CHECKS =>
      'doc_auth.errors.alerts.doc_number_checks',
    # i18n-tasks-use t('doc_auth.errors.doc.doc_type_check')
    DocAuth::Errors::DOC_TYPE_CHECK =>
      'doc_auth.errors.doc.doc_type_check',
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
    # i18n-tasks-use t('doc_auth.errors.general.selfie_failure')
    DocAuth::Errors::SELFIE_FAILURE => 'doc_auth.errors.general.selfie_failure',
    # i18n-tasks-use t('doc_auth.errors.alerts.selfie_not_live_or_poor_quality')
    DocAuth::Errors::SELFIE_NOT_LIVE_OR_POOR_QUALITY =>
      'doc_auth.errors.alerts.selfie_not_live_or_poor_quality',
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
    # i18n-tasks-use t('doc_auth.errors.http.image_load.top_msg')
    DocAuth::Errors::IMAGE_LOAD_FAILURE => 'doc_auth.errors.http.image_load.top_msg',
    # i18n-tasks-use t('doc_auth.errors.http.image_load.failed_short')
    DocAuth::Errors::IMAGE_LOAD_FAILURE_FIELD => 'doc_auth.errors.http.image_load.failed_short',
    # i18n-tasks-use t('doc_auth.errors.http.pixel_depth.top_msg')
    DocAuth::Errors::PIXEL_DEPTH_FAILURE => 'doc_auth.errors.http.pixel_depth.top_msg',
    # i18n-tasks-use t('doc_auth.errors.http.pixel_depth.failed_short')
    DocAuth::Errors::PIXEL_DEPTH_FAILURE_FIELD => 'doc_auth.errors.http.pixel_depth.failed_short',
    # i18n-tasks-use t('doc_auth.errors.http.image_size.top_msg')
    DocAuth::Errors::IMAGE_SIZE_FAILURE => 'doc_auth.errors.http.image_size.top_msg',
    # i18n-tasks-use t('doc_auth.errors.http.image_size.failed_short')
    DocAuth::Errors::IMAGE_SIZE_FAILURE_FIELD => 'doc_auth.errors.http.image_size.failed_short',
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
      error_keys = DocAuth::ErrorGenerator::ERROR_KEYS.dup

      error_keys.each do |category|
        cat_errors = response.errors[category]
        next unless cat_errors
        translated_cat_errors = cat_errors.map do |plain_error|
          error_key = ERROR_TRANSLATIONS[plain_error]
          if error_key
            I18n.t(error_key)
          else
            Rails.logger.warn("unknown DocAuth error=#{plain_error}")
            I18n.t('doc_auth.errors.general.no_liveness')
          end
        end
        response.errors[category] = translated_cat_errors
      end
    end

    def translate_generic_errors!(response)
      if response.errors[:network] == true
        response.errors[:network] = I18n.t('doc_auth.errors.general.network_error')
      end
    end
  end

  # rubocop:disable Layout/LineLength
  # @param [Proc,nil] warn_notifier proc takes a hash, and should log that hash to events.log
  def self.client(vendor:, warn_notifier: nil)
    case vendor
    when Idp::Constants::Vendors::LEXIS_NEXIS, 'lexisnexis' # Use constant once configured in prod
      DocAuthErrorTranslatorProxy.new(
        DocAuth::LexisNexis::LexisNexisClient.new(
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
          trueid_account_id: IdentityConfig.store.lexisnexis_trueid_account_id,
          trueid_noliveness_cropping_workflow: IdentityConfig.store.lexisnexis_trueid_noliveness_cropping_workflow,
          trueid_noliveness_nocropping_workflow: IdentityConfig.store.lexisnexis_trueid_noliveness_nocropping_workflow,
          trueid_liveness_cropping_workflow: IdentityConfig.store.lexisnexis_trueid_liveness_cropping_workflow,
          trueid_liveness_nocropping_workflow: IdentityConfig.store.lexisnexis_trueid_liveness_nocropping_workflow,
          trueid_password: IdentityConfig.store.lexisnexis_trueid_password,
          trueid_username: IdentityConfig.store.lexisnexis_trueid_username,
          hmac_key_id: IdentityConfig.store.lexisnexis_trueid_hmac_key_id,
          hmac_secret_key: IdentityConfig.store.lexisnexis_trueid_hmac_secret_key,
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
      raise "#{vendor} is not a valid doc auth vendor"
    end
  end
  # rubocop:enable Layout/LineLength

  def self.doc_auth_vendor_for_bucket(bucket)
    case bucket
    when :socure
      Idp::Constants::Vendors::SOCURE
    when :lexis_nexis
      Idp::Constants::Vendors::LEXIS_NEXIS
    when :mock
      Idp::Constants::Vendors::MOCK
    else # e.g., nil
      IdentityConfig.store.doc_auth_vendor_default
    end
  end

  def self.doc_auth_vendor( # is this used anywhere?
    request:,
    service_provider:,
    session:,
    user:,
    user_session:
  )
    bucket = AbTests::DOC_AUTH_VENDOR.bucket(
      request:,
      service_provider:,
      session:,
      user:,
      user_session:,
    )

    doc_auth_vendor_for_bucket(bucket)
  end
end
