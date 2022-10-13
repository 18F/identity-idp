# Handles the INTERNAL redirect which happens when a service provider authentication request
# is passed through the IDP's authentication flow (sign-in, MFA, etc.)
# The original request was saved to the sp_session object, so we retrieve it to pass on the
# original request url in the form of a POST request to the SamlIdpController#auth method
class SamlCompletionController < ApplicationController
  # Pass the original service provider request to the main SamlIdpController#auth method
  # via a POST with form parameters replacing the url query parameters
  def index
    if sp_session.present?
      request_url = URI(sp_session[:request_url])
      action_url =  api_saml_finalauthpost_url(path_year: params[:path_year])

      # Takes the query params which were set internally in the
      # sp_session (so they should always be valid).
      # A bad request that originated outside of the IDP would have
      # already responded with a 400 status before reaching this point.
      form_params = UriService.params(request_url)

      render 'shared/saml_post_form', locals: { action_url: action_url, form_params: form_params },
                                      layout: false
    else
      render_not_found
    end
  end
end
