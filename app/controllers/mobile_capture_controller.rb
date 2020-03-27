class MobileCaptureController < ApplicationController
  def new
    SecureHeaders.append_content_security_policy_directives(request,
                                                            script_src: ['\'unsafe-eval\''])
    render layout: false
  end
end
