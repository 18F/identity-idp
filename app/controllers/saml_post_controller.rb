class SamlPostController < ApplicationController
  after_action -> { request.session_options[:skip] = true }, only: :auth
  skip_before_action :verify_authenticity_token

  def auth
    path_year = request.path[-4..-1]
    path_method = "api_saml_authpost#{path_year}_url"
    action_url = Rails.application.routes.url_helpers.send(path_method)

    form_params = params.permit(:SAMLRequest, :RelayState, :SigAlg, :Signature)

    render 'shared/saml_post_form',
           locals: { action_url: action_url, form_params: form_params },
           layout: false
  end
end
