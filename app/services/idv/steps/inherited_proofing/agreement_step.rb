module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def call
          Rails.logger.info('DEBUG: entering AgreementStep#call')
          flow_session[:pii_from_user] = { phone: '303-555-1212' }  # dependent upon SessionEncryptor::SENSITIVE_PATHS
        end

        def form_submit
          Idv::ConsentForm.new.submit(consent_form_params)
        end

        def consent_form_params
          params.require(:inherited_proofing).permit(:ial2_consent_given)
        end
      end
    end
  end
end
