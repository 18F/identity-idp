# frozen_string_literal: true

module DocAuth
  class ErrorGenerator
    attr_reader :config

    def initialize(config)
      @config = config
    end

    # These constants are the key names for the TrueID errors hash that is returned
    ID = :id
    FRONT = :front
    BACK = :back
    SELFIE = :selfie
    GENERAL = :general

    ERROR_KEYS = [
      ID,
      FRONT,
      BACK,
      SELFIE,
      GENERAL,
    ].to_set.freeze

    ALERT_MESSAGES = {
      '1D Control Number Valid': { type: BACK, msg_key: Errors::REF_CONTROL_NUMBER_CHECK },
      '2D Barcode Content': { type: BACK, msg_key: Errors::BARCODE_CONTENT_CHECK },
      '2D Barcode Read': { type: BACK, msg_key: Errors::BARCODE_READ_CHECK },
      'Birth Date Crosscheck': { type: ID, msg_key: Errors::BIRTH_DATE_CHECKS },
      'Birth Date Valid': { type: ID, msg_key: Errors::BIRTH_DATE_CHECKS },
      'Control Number Crosscheck': { type: BACK, msg_key: Errors::CONTROL_NUMBER_CHECK },
      'Document Classification': { type: ID, msg_key: Errors::ID_NOT_RECOGNIZED },
      'Document Crosscheck Aggregation': { type: ID, msg_key: Errors::DOC_CROSSCHECK },
      'Document Expired': { type: ID, msg_key: Errors::DOCUMENT_EXPIRED_CHECK },
      'Document Number Crosscheck': { type: ID, msg_key: Errors::DOC_NUMBER_CHECKS },
      'Expiration Date Crosscheck': { type: ID, msg_key: Errors::EXPIRATION_CHECKS },
      'Expiration Date Valid': { type: ID, msg_key: Errors::EXPIRATION_CHECKS },
      'Full Name Crosscheck': { type: ID, msg_key: Errors::FULL_NAME_CHECK },
      'Issue Date Crosscheck': { type: ID, msg_key: Errors::ISSUE_DATE_CHECKS },
      'Issue Date Valid': { type: ID, msg_key: Errors::ISSUE_DATE_CHECKS },
      'Layout Valid': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Near-Infrared Response': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Photo Printing': { type: FRONT, msg_key: Errors::VISIBLE_PHOTO_CHECK },
      'Physical Document Presence': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Sex Crosscheck': { type: ID, msg_key: Errors::SEX_CHECK },
      'Visible Color Response': { type: ID, msg_key: Errors::VISIBLE_COLOR_CHECK },
      'Visible Pattern': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Visible Photo Characteristics': { type: FRONT, msg_key: Errors::VISIBLE_PHOTO_CHECK },
    }.freeze

    def generate_doc_auth_errors(response_info)
      liveness_enabled = response_info[:liveness_enabled]
      alert_error_count = response_info[:doc_auth_result] == 'Passed' ?
        0 : response_info[:alert_failure_count]

      unknown_fail_count = scan_for_unknown_alerts(response_info)
      alert_error_count -= unknown_fail_count

      image_metric_errors = get_image_metric_errors(response_info[:image_metrics])
      return image_metric_errors.to_h unless image_metric_errors.empty?

      alert_errors = get_error_messages(liveness_enabled, response_info)
      alert_error_count += 1 if alert_errors.include?(SELFIE)

      error = ''
      side = nil

      if alert_error_count < 1
        config.warn_notifier&.call(
          message: 'DocAuth failure escaped without useful errors',
          response_info: response_info,
        )

        error = Errors::GENERAL_ERROR
        side = ID
      elsif alert_error_count == 1
        error = alert_errors.values[0].to_a.pop
        side = alert_errors.keys[0]
      elsif alert_error_count > 1
        # Simplify multiple errors into a single error for the user
        error_fields = alert_errors.keys
        if error_fields.length == 1
          side = error_fields.first
          case side
          when ID
            error = Errors::GENERAL_ERROR
          when FRONT
            error = Errors::MULTIPLE_FRONT_ID_FAILURES
          when BACK
            error = Errors::MULTIPLE_BACK_ID_FAILURES
          end
        elsif error_fields.length > 1
          error = Errors::GENERAL_ERROR
          side = ID
        end
      end

      ErrorResult.new(error, side).to_h
    end

    # private

    def get_image_metric_errors(processed_image_metrics)
      dpi_threshold = config&.dpi_threshold&.to_i || 290
      sharpness_threshold = config&.sharpness_threshold&.to_i || 40
      glare_threshold = config&.glare_threshold&.to_i || 40

      dpi_metrics, sharp_metrics, glare_metrics = {}, {}, {}
      error_result = ErrorResult.new

      processed_image_metrics.each do |side, img_metrics|
        dpi_metrics[side] = img_metrics.slice('HorizontalResolution', 'VerticalResolution')
        sharp_metrics[side] = img_metrics.slice('SharpnessMetric')
        glare_metrics[side] = img_metrics.slice('GlareMetric')
      end

      dpi_metrics.each do |side, img_metrics|
        hdpi = img_metrics['HorizontalResolution']&.to_i || 0
        vdpi = img_metrics['VerticalResolution']&.to_i || 0
        if hdpi < dpi_threshold || vdpi < dpi_threshold
          error_result.set_error(Errors::DPI_LOW)
          error_result.add_side(side)
        end
      end
      return error_result unless error_result.empty?

      sharp_metrics.each do |side, img_metrics|
        sharpness = img_metrics['SharpnessMetric']&.to_i
        if sharpness.present? && sharpness < sharpness_threshold
          error_result.set_error(Errors::SHARP_LOW)
          error_result.add_side(side)
        end
      end
      return error_result unless error_result.empty?

      glare_metrics.each do |side, img_metrics|
        glare = img_metrics['GlareMetric']&.to_i
        if glare.present? && glare < glare_threshold
          error_result.set_error(Errors::GLARE_LOW)
          error_result.add_side(side)
        end
      end

      error_result
    end

    def get_error_messages(liveness_enabled, response_info)
      errors = Hash.new { |hash, key| hash[key] = Set.new }

      if response_info[:doc_auth_result] != 'Passed'
        response_info[:processed_alerts][:failed]&.each do |alert|
          alert_msg_hash = ALERT_MESSAGES[alert[:name].to_sym]

          if alert_msg_hash.present?
            field_type = alert[:side] || alert_msg_hash[:type]
            errors[field_type.to_sym] << alert_msg_hash[:msg_key]
          end
        end
      end

      portrait_match_results = response_info[:portrait_match_results] || {}
      if liveness_enabled && portrait_match_results.dig(:FaceMatchResult) != 'Pass'
        errors[SELFIE] << Errors::SELFIE_FAILURE
      end

      errors
    end

    def scan_for_unknown_alerts(response_info)
      all_alerts = [
        *response_info[:processed_alerts][:failed],
        *response_info[:processed_alerts][:passed],
      ]
      unknown_fail_count = 0

      unknown_alerts = []
      all_alerts.each do |alert|
        if ALERT_MESSAGES[alert[:name].to_sym].blank?
          unknown_alerts.push(alert[:name])

          unknown_fail_count += 1 if alert[:result] != 'Passed'
        end
      end

      return 0 if unknown_alerts.empty?

      config.warn_notifier&.call(
        message: 'DocAuth vendor responded with alert name(s) we do not handle',
        unknown_alerts: unknown_alerts,
        response_info: response_info,
      )

      unknown_fail_count
    end

    def self.wrapped_general_error
      { general: [Errors::GENERAL_ERROR], hints: true }
    end
  end
end
