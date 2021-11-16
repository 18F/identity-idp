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
      'Photo Printing': {type: FRONT, msg_key: Errors::VISIBLE_PHOTO_CHECK },
      'Physical Document Presence': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Sex Crosscheck': { type: ID, msg_key: Errors::SEX_CHECK },
      'Visible Color Response': { type: ID, msg_key: Errors::VISIBLE_COLOR_CHECK },
      'Visible Pattern': { type: ID, msg_key: Errors::ID_NOT_VERIFIED },
      'Visible Photo Characteristics': { type: FRONT, msg_key: Errors::VISIBLE_PHOTO_CHECK },
    }.freeze

    # rubocop:disable Metrics/PerceivedComplexity
    def generate_doc_auth_errors(response_info)
      liveness_enabled = response_info[:liveness_enabled]
      alert_error_count = response_info[:alert_failure_count]

      unknown_fail_count = scan_for_unknown_alerts(response_info)
      alert_error_count -= unknown_fail_count

      image_metric_errors = get_image_metric_errors(response_info[:image_metrics])
      return image_metric_errors unless image_metric_errors.empty?

      errors = get_error_messages(liveness_enabled, response_info)
      alert_error_count += 1 if errors.include?(SELFIE)

      if alert_error_count < 1
        config.warn_notifier&.call(
          message: 'DocAuth failure escaped without useful errors',
          response_info: response_info,
        )

        return self.class.wrapped_general_error(liveness_enabled)
      # if the alert_error_count is 1 it is just passed along
      elsif alert_error_count > 1
        # Simplify multiple errors into a single error for the user
        error_fields = errors.keys
        if error_fields.length == 1
          case error_fields.first
          when ID
            errors[ID] = Set[self.class.general_error(false)]
          when FRONT
            errors[ID] = Set[Errors::MULTIPLE_FRONT_ID_FAILURES]
            errors.delete(FRONT)
          when BACK
            errors[ID] = Set[Errors::MULTIPLE_BACK_ID_FAILURES]
            errors.delete(BACK)
          end
        elsif error_fields.length > 1
          return self.class.wrapped_general_error(liveness_enabled) if error_fields.include?(SELFIE)

          # If we don't have a selfie error don't give the message suggesting retaking selfie.
          return self.class.wrapped_general_error(false)
        end
      end

      errors.transform_values(&:to_a)
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # private

    def get_image_metric_errors(processed_image_metrics)
      dpi_threshold = config&.dpi_threshold&.to_i || 290
      sharpness_threshold = config&.sharpness_threshold&.to_i || 40
      glare_threshold = config&.glare_threshold&.to_i || 40

      front_dpi_fail, back_dpi_fail = false, false
      front_sharp_fail, back_sharp_fail = false, false
      front_glare_fail, back_glare_fail = false, false

      processed_image_metrics.each do |side, img_metrics|
        hdpi = img_metrics['HorizontalResolution']&.to_i || 0
        vdpi = img_metrics['VerticalResolution']&.to_i || 0
        if hdpi < dpi_threshold || vdpi < dpi_threshold
          front_dpi_fail = true if side == :front
          back_dpi_fail = true if side == :back
        end

        sharpness = img_metrics['SharpnessMetric']&.to_i
        if sharpness.present? && sharpness < sharpness_threshold
          front_sharp_fail = true if side == :front
          back_sharp_fail = true if side == :back
        end

        glare = img_metrics['GlareMetric']&.to_i
        if glare.present? && glare < glare_threshold
          front_glare_fail = true if side == :front
          back_glare_fail = true if side == :back
        end
      end

      return { GENERAL => [Errors::DPI_LOW_BOTH_SIDES] } if front_dpi_fail && back_dpi_fail
      return { GENERAL => [Errors::DPI_LOW_ONE_SIDE] } if front_dpi_fail || back_dpi_fail

      return { GENERAL => [Errors::SHARP_LOW_BOTH_SIDES] } if front_sharp_fail && back_sharp_fail
      return { GENERAL => [Errors::SHARP_LOW_ONE_SIDE] } if front_sharp_fail || back_sharp_fail

      return { GENERAL => [Errors::GLARE_LOW_BOTH_SIDES] } if front_glare_fail && back_glare_fail
      return { GENERAL => [Errors::GLARE_LOW_ONE_SIDE] } if front_glare_fail || back_glare_fail

      {}
    end

    def get_error_messages(liveness_enabled, response_info)
      errors = Hash.new { |hash, key| hash[key] = Set.new }

      if response_info[:doc_auth_result] != 'Passed'
        response_info[:processed_alerts][:failed]&.each do |alert|
          alert_msg_hash = ALERT_MESSAGES[alert[:name].to_sym]

          errors[alert_msg_hash[:type]] << alert_msg_hash[:msg_key] if alert_msg_hash.present?
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

    def self.general_error(liveness_enabled)
      liveness_enabled ? Errors::GENERAL_ERROR_LIVENESS : Errors::GENERAL_ERROR_NO_LIVENESS
    end

    def self.wrapped_general_error(liveness_enabled)
      { general: [ErrorGenerator.general_error(liveness_enabled)] }
    end
  end
end
