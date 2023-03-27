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

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(
        uuid: flow_session[document_capture_session_uuid_key],
      )
    end

    def document_capture_session_uuid_key
      :document_capture_session_uuid
    end
  end
end
