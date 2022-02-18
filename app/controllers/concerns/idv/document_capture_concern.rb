module Idv
  module DocumentCaptureConcern
    def override_document_capture_step_csp
      return if params[:step] != 'document_capture'

      override_document_capture_step_csp_with_rails_csp_tooling
    end

    def override_document_capture_step_csp_with_secure_headers
      SecureHeaders.append_content_security_policy_directives(
        request,
        # required to run wasm until wasm-eval is available
        script_src: ['\'unsafe-eval\''],
        # required because acuant styles its own elements with inline style attributes
        style_src: ['\'unsafe-inline\''],
        # required for retrieving image dimensions from uploaded images
        img_src: ['blob:'],
      )
    end

    def override_document_capture_step_csp_with_rails_csp_tooling
      policy = current_content_security_policy
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end
  end
end
