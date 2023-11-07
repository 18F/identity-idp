# Handles the INTERNAL redirect which happens when a service provider authentication request
# is passed through the IDP's authentication flow (sign-in, MFA, etc.)
# The original request was saved to the sp_session object, so we retrieve it to pass on the
# original request url in the form of a POST request to the SamlIdpController#auth method
class SamlCompletionController < ApplicationController
  # Pass the original service provider request to the main SamlIdpController#auth method
  # via a POST with form parameters replacing the url query parameters
  before_action :verify_sp_session_exists

  def index
    request_url = URI(sp_session[:request_url])
    path_year = request_url.path[-4..-1]
    action_path = api_saml_finalauthpost_path(path_year:)
    if !valid_path?(action_path)
      render_not_found
      return
    end

    # Takes the query params which were set internally in the
    # sp_session (so they should always be valid).
    # A bad request that originated outside of the IDP would have
    # already responded with a 400 status before reaching this point.
    form_params = UriService.params(request_url)

    render 'shared/saml_post_form', locals: { action_url: action_path, form_params: },
                                    layout: false
  end

  def verify_sp_session_exists
    render_not_found unless sp_session.present? && sp_session[:request_url].present?
  end

  def valid_path?(action_path)
    recognized_path = Rails.application.routes.recognize_path(action_path, method: :post)
    recognized_path[:controller] == 'saml_idp' && recognized_path[:action] == 'auth'
  end
end
