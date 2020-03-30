class MobileCaptureController < ApplicationController
  def new
    # required to run wasm until wasm-eval is available
    SecureHeaders.append_content_security_policy_directives(request,
                                                            script_src: ['\'unsafe-eval\''])
    render layout: false
  end
end
