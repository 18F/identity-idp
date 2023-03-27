module Idv
  module DocumentCaptureConcern
    def override_document_capture_step_csp
      if !IdentityConfig.store.doc_auth_document_capture_controller_enabled
        return if params[:step] != 'document_capture'
      end

      policy = current_content_security_policy
      policy.connect_src(*policy.connect_src, 'us.acas.acuant.net')
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end
  end
end
