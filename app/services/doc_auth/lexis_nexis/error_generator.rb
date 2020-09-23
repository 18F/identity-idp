module DocAuth
  module LexisNexis
    class UnknownTrueIDError < StandardError; end

    class ErrorGenerator
      # These constants are the key names for the TrueID errors hash that is returned
      ID = 'id'.to_sym
      FRONT = 'front'.to_sym
      BACK = 'back'.to_sym

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

      def self.generate_trueid_errors(response_info, liveness_checking_enabled)
        errors = Hash.new { |hash, key| hash[key] = Set.new }

        if response_info[:DocAuthResult] != 'Passed'
          response_info[:Alerts]&.each do |alert|
            alert_msg_hash = TRUE_ID_MESSAGES[alert[:name].to_sym]

            if alert_msg_hash.present?
              # Don't show alert errors if the DocAuthResult has passed
              # With liveness turned on DocAuthResult can pass but the liveness check fails
              if response_info[:DocAuthResult] != 'Passed' && alert[:result] != 'Passed'
                # We should log the counts of failing alerts that are given to users for analytics
                # AM: Log to Ahoy/Cloudwatch
                errors[alert_msg_hash[:type]].add(I18n.t(alert_msg_hash[:msg_key]))
              end
            else
              # We always want to make sure any unknown alerts that come through are noted
              # AM: Log to Ahoy/Cloudwatch
            end
          end
        end

        selfie_results = response_info[:PortraitMatchResults]
        if selfie_results.present? && selfie_results.dig(:FaceMatchResult) != "Pass" && response_info[:DocAuthResult] == 'Passed'
            errors[:selfie].add(I18n.t('doc_auth.errors.lexis_nexis.selfie_failure'))
        else
          # Should probably log if selfie results isn't populated when we expect it to be?
        end

        if errors.empty?
          e = UnknownTrueIDError.new("TrueID failure escaped without useful errors")
          # AM: Log to Ahoy/Cloudwatch
          NewRelic::Agent.notice_error(e, { custom_params: { response_info: response_info } })

          if liveness_checking_enabled
            errors[:general].add(I18n.t('doc_auth.errors.lexis_nexis.general_error_liveness'))
          else
            errors[:general].add(I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness'))
          end
        end

        errors.transform_values(&:to_a)
      end
    end
  end
end
