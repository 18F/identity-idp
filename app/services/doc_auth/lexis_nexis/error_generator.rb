module DocAuth
  module LexisNexis
    class UnknownTrueIDError < StandardError; end

    class ErrorGenerator
      # These constants are the key names for the TrueID errors hash that is returned
      ID = 'id'.to_sym
      FRONT = 'front'.to_sym
      BACK = 'back'.to_sym

      TRUE_ID_MESSAGES = {
        '1D Control Number Valid': { type: BACK, message: I18n.t('doc_auth.errors.lexis_nexis.1d_control_number_check')},
        '2D Barcode Content': { type: BACK, message: I18n.t('doc_auth.errors.lexis_nexis.barcode_content_check')},
        '2D Barcode Read': { type: BACK, message: I18n.t('doc_auth.errors.lexis_nexis.barcode_read_check')},
        'Birth Date Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')},
        'Birth Date Valid': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.birth_date_checks')}, # I'm not sure about the type here this could be front only
        'Control Number Crosscheck': { type: BACK, message: I18n.t('doc_auth.errors.lexis_nexis.control_number_check')},
        'Document Classification': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.id_not_recognized')},
        'Document Crosscheck Aggregation': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.doc_crosscheck')},
        'Document Expired': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.expiration_checks')},
        'Document Number Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.doc_number_checks')},
        'Expiration Date Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.expiration_checks')},
        'Expiration Date Valid': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.expiration_checks')}, # I'm not sure about the type here this could be front only
        'Full Name Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.full_name_check')},
        'Issue Date Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.issue_date_checks')},
        'Issue Date Valid': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.issue_date_checks')}, # I'm not sure about the type here this could be front only
        'Layout Valid': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.id_not_verified')}, # We may be able to use region to modify this to back
        'Near-Infrared Response': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.id_not_verified')}, # This may not ever be returned in our use case
        'Sex Crosscheck': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.sex_check')},
        'Visible Color Response': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.visible_color_check')},
        'Visible Pattern': { type: ID, message: I18n.t('doc_auth.errors.lexis_nexis.id_not_verified')}, # I'm not sure about the type here this could be front only
        'Visible Photo Characteristics': { type: FRONT, message: I18n.t('doc_auth.errors.lexis_nexis.visible_photo_check')}, # This may not ever be returned in our use case
      }.freeze

      def self.generate_trueid_errors(response_info, liveness_checking_enabled)
        errors = Hash.new { |hash, key| hash[key] = Set.new }

        if response_info[:DocAuthResult] != 'Passed'
          response_info[:Alerts]&.each do |alert|
            alert_msg_hash = TRUE_ID_MESSAGES[alert[:name].to_sym]

            if alert_msg_hash.present?
              # Don't show alert errors if the DocAuthResult has passed
              # With liveness turned on DocAuthResult can pass but the liveness check fails
              if response_info[:DocAuthResult] != 'Passed' && alert[:result] != 'Passed'
                # We should log to get counts of the failing alerts that are given back to users for analytics
                # AM: Log to Ahoy/Cloudwatch
                errors[alert_msg_hash[:type]].add(alert_msg_hash[:message])
              end
            else
              # We always want to make sure any unknown alerts that come through are noted
              # AM: Log to Ahoy/Cloudwatch
            end
          end
        end

        selfie_results = response_info[:PortraitMatchResults]
        if selfie_results.present? && selfie_results.dig(:FaceMatchResult) != "Pass"
          errors[:selfie].add(I18n.t('doc_auth.errors.lexis_nexis.selfie_failure'))
        end
        # Should probably log if selfie results isn't populated when we expect it to be?

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

        return errors.transform_values(&:to_a)
      end
    end
  end
end

