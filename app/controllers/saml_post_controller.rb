class SamlPostController < ApplicationController
  after_action -> { request.session_options[:skip] = true }, only: :auth
  skip_before_action :verify_authenticity_token

  def auth
    action_url = api_saml_authpost_url(path_year: params[:path_year])

    form_params = params.permit(:SAMLRequest, :RelayState, :SigAlg, :Signature)

    render 'shared/saml_post_form', locals: { action_url: action_url, form_params: form_params },
                                    layout: false
  end
end
