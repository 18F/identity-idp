module Idv
  module DocumentCaptureConcern
    def override_document_capture_step_csp
      return if params[:step] != 'document_capture'

      policy = current_content_security_policy
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end
  end
end
