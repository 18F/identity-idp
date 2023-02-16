module Idv
  module StepUtilitiesConcern
    extend ActiveSupport::Concern

    def flow_session
      user_session['idv/doc_auth']
    end

    # copied from doc_auth_controller
    def flow_path
      flow_session[:flow_path]
    end

    def confirm_pii_from_doc
      @pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if @pii.present?
      flow_session.delete('Idv::Steps::DocumentCaptureStep')
      redirect_to idv_doc_auth_url
    end

    # Copied from capture_doc_flow.rb
    # and from doc_auth_flow.rb
    def acuant_sdk_ab_test_analytics_args
      capture_session_uuid = flow_session[:document_capture_session_uuid]
      if capture_session_uuid
        {
          acuant_sdk_upgrade_ab_test_bucket:
            AbTests::ACUANT_SDK.bucket(capture_session_uuid),
        }
      else
        {}
      end
    end

    def irs_reproofing?
      effective_user&.decorate&.reproof_for_irs?(
        service_provider: current_sp,
      ).present?
    end
  end
end
