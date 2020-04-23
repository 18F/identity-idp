module Idv
  class DocAuthV2Controller < DocAuthController
    FSM_SETTINGS = {
      step_url: :idv_doc_auth_v2_step_url,
      final_url: :idv_review_url,
      flow: Idv::Flows::DocAuthV2Flow,
      analytics_id: Analytics::DOC_AUTH_V2,
    }.freeze

    def flow_session
      user_session['idv/doc_auth_v2']
    end
  end
end
