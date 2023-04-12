class SamlPostController < ApplicationController
  after_action -> { request.session_options[:skip] = true }, only: :auth
  skip_before_action :verify_authenticity_token

  def auth
    action_url = build_action_url(request.path)
    if !action_url
      render_not_found
      return
    end

    form_params = params.permit(:SAMLRequest, :RelayState, :SigAlg, :Signature)

    render 'shared/saml_post_form', locals: { action_url: action_url, form_params: form_params },
                                    layout: false
  end

  private

  def build_action_url(path)
    path_year = path[-4..-1]
    path = "/api/saml/authpost#{path_year}"
    recognized_path = Rails.application.routes.recognize_path(path, method: :post)

    path if recognized_path[:controller] == 'saml_idp' && recognized_path[:action] == 'auth'
  end
end
