module DocAuth
  module LexisNexis
    class UnknownTrueIDError < StandardError; end
    class UnknownTrueIDAlert < StandardError; end

    class ErrorGenerator
      # These constants are the key names for the TrueID errors hash that is returned
      ID = :id
      FRONT = :front
      BACK = :back
      SELFIE = :selfie
      GENERAL = :general

      # rubocop:disable Layout/LineLength
      TRUE_ID_MESSAGES = {
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.ref_control_number_check')
        '1D Control Number Valid': { type: BACK, msg_key: 'doc_auth.errors.lexis_nexis.ref_control_number_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.barcode_content_check')
        '2D Barcode Content': { type: BACK, msg_key: 'doc_auth.errors.lexis_nexis.barcode_content_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.barcode_read_check')
        '2D Barcode Read': { type: BACK, msg_key: 'doc_auth.errors.lexis_nexis.barcode_read_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.birth_date_checks')
        'Birth Date Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.birth_date_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.birth_date_checks')
        'Birth Date Valid': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.birth_date_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.control_number_check')
        'Control Number Crosscheck': { type: BACK, msg_key: 'doc_auth.errors.lexis_nexis.control_number_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.id_not_recognized')
        'Document Classification': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.id_not_recognized' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.doc_crosscheck')
        'Document Crosscheck Aggregation': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.doc_crosscheck' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.expiration_checks')
        'Document Expired': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.expiration_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.doc_number_checks')
        'Document Number Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.doc_number_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.expiration_checks')
        'Expiration Date Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.expiration_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.expiration_checks')
        'Expiration Date Valid': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.expiration_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.full_name_check')
        'Full Name Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.full_name_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.issue_date_checks')
        'Issue Date Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.issue_date_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.issue_date_checks')
        'Issue Date Valid': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.issue_date_checks' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.id_not_verified')
        'Layout Valid': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.id_not_verified' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.id_not_verified')
        'Near-Infrared Response': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.id_not_verified' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.sex_check')
        'Sex Crosscheck': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.sex_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.visible_color_check')
        'Visible Color Response': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.visible_color_check' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.id_not_verified')
        'Visible Pattern': { type: ID, msg_key: 'doc_auth.errors.lexis_nexis.id_not_verified' },
        # i18n-tasks-use t('doc_auth.errors.lexis_nexis.visible_photo_check')
        'Visible Photo Characteristics': { type: FRONT, msg_key: 'doc_auth.errors.lexis_nexis.visible_photo_check' },
      }.freeze
      # rubocop:enable Layout/LineLength

      # rubocop:disable Metrics/PerceivedComplexity
      def self.generate_trueid_errors(response_info, liveness_enabled)
        user_error_count = response_info[:AlertFailureCount]

        errors = get_error_messages(liveness_enabled, response_info)
        user_error_count += 1 if errors.include?(SELFIE)

        scan_for_unknown_alerts(response_info)

        if user_error_count.zero?
          e = UnknownTrueIDError.new('LN TrueID failure escaped without useful errors')
          NewRelic::Agent.notice_error(e, { custom_params: { response_info: response_info } })

          return { GENERAL => [general_error(liveness_enabled)] }
        # if the user_error_count is 1 it is just passed along
        elsif user_error_count > 1
          # Simplify multiple errors into a single error for the user
          error_fields = errors.keys
          if error_fields.length == 1
            case error_fields.first
            when ID
              errors[ID] = Set[general_error(false)]
            when FRONT
              errors[FRONT] = Set[I18n.t('doc_auth.errors.lexis_nexis.multiple_front_id_failures')]
            when BACK
              errors[BACK] = Set[I18n.t('doc_auth.errors.lexis_nexis.multiple_back_id_failures')]
            end
          elsif error_fields.length > 1
            return { GENERAL => [general_error(liveness_enabled)] } if error_fields.include?(SELFIE)

            # If we don't have a selfie error don't give the message suggesting retaking selfie.
            return { GENERAL => [general_error(false)] }
          end
        end

        errors.transform_values(&:to_a)
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # private

      def self.get_error_messages(liveness_enabled, response_info)
        errors = Hash.new { |hash, key| hash[key] = Set.new }

        if response_info[:DocAuthResult] != 'Passed'
          response_info[:Alerts][:failed]&.each do |alert|
            alert_msg_hash = TRUE_ID_MESSAGES[alert[:name].to_sym]

            if alert_msg_hash.present?
              errors[alert_msg_hash[:type]].add(I18n.t(alert_msg_hash[:msg_key]))
            end
          end
        end

        pm_results = response_info[:PortraitMatchResults] || {}
        if liveness_enabled && pm_results.dig(:FaceMatchResult) != 'Pass'
          errors[SELFIE].add(I18n.t('doc_auth.errors.lexis_nexis.selfie_failure'))
        end

        errors
      end

      def self.general_error(liveness_enabled)
        if liveness_enabled
          I18n.t('doc_auth.errors.lexis_nexis.general_error_liveness')
        else
          I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')
        end
      end

      def self.scan_for_unknown_alerts(response_info)
        all_alerts = [*response_info[:Alerts][:failed], *response_info[:Alerts][:passed]]

        unknown_alerts = []
        all_alerts.each do |alert|
          unknown_alerts.push(alert[:name]) if TRUE_ID_MESSAGES[alert[:name].to_sym].blank?
        end

        return if unknown_alerts.empty?

        message = 'LN TrueID responded with alert name(s) we do not handle: ' + unknown_alerts.to_s
        e = UnknownTrueIDAlert.new(message)
        NewRelic::Agent.notice_error(e, { custom_params: { response_info: response_info } })
      end

      private_class_method :get_error_messages, :general_error, :scan_for_unknown_alerts
    end
  end
end
