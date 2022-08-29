module Idv
  module Steps
    module InheritedProofing
      class AgreementStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def call
        end

        def form_submit
          skip_to_capture if params[:skip_upload]

          Idv::ConsentForm.new.submit(consent_form_params)
        end

        def skip_to_capture
          # See: Idv::DocAuthController#update_if_skipping_upload
          flow_session[:skip_upload_step] = true
        end

        def consent_form_params
          params.require(:doc_auth).permit(:ial2_consent_given)
        end
      end
    end
  end
end
