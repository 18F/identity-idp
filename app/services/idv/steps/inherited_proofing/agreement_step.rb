module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < InheritedProofingBaseStep
        include UserPiiManagable

        STEP_INDICATOR_STEP = :getting_started

        def call
          inherited_proofing_save_user_pii_to_session!
          inherited_proofing_form_response
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
