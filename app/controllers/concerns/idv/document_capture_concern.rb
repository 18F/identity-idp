module Idv
  module DocumentCaptureConcern
    def override_document_capture_step_csp
      return if params[:step] != 'document_capture'

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
  end
end
