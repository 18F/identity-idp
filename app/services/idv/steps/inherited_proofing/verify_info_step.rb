module Idv
  module Steps
    module InheritedProofing
      class VerifyInfoStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :verify_info
        def call
          Rails.logger.info('DEBUG: entering VerifyInfoStep#call')
          Rails.logger.info { "DEBUG: flow_session = #{flow_session.inspect}" }

          save_legacy_state

          Rails.logger.info { "DEBUG: idv_session = #{idv_session.inspect}" }
        end

        def pii
          {
            first_name: 'Jake',
            last_name: 'Jabs'
          }
        end

        def save_legacy_state   # can we NOT name it legacy?!
          skip_legacy_steps
          idv_session['applicant'] = pii
          idv_session['applicant'][:uuid] = current_user&.uuid || 'uh_oh_uuid_not_in_current_user'  # works!, sets uuid
        end

        def skip_legacy_steps
          idv_session['profile_confirmation'] = true
          idv_session['vendor_phone_confirmation'] = false  # these may avert the /verify/review parse_legacy error
          idv_session['user_phone_confirmation'] = false
          idv_session['address_verification_mechanism'] = 'phone'
          idv_session['resolution_successful'] = 'phone'
        end
      end
    end
  end
end
