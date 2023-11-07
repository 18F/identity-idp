class SamlPostController < ApplicationController
  after_action -> { request.session_options[:skip] = true }, only: :auth
  skip_before_action :verify_authenticity_token

  def auth
    action_url = api_saml_authpost_path(path_year: params[:path_year])
    if !valid_path?(action_url)
      render_not_found
      return
    end

    form_params = params.permit(:SAMLRequest, :RelayState, :SigAlg, :Signature)

    render 'shared/saml_post_form', locals: { action_url:, form_params: },
                                    layout: false
  end

  private

  def valid_path?(action_path)
    recognized_path = Rails.application.routes.recognize_path(action_path, method: :post)
    recognized_path[:controller] == 'saml_idp' && recognized_path[:action] == 'auth'
  end
end
