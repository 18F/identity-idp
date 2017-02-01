module SignUp
  class CompletionsController < ApplicationController
    def show
      if user_fully_authenticated? && session[:sp].present?
        analytics.track_event(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
          service_provider_attributes
        )
      else
        redirect_to new_user_session_url
      end
    end

    def update
      analytics.track_event(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE,
        service_provider_attributes
      )
      redirect_to session[:saml_request_url]
    end

    private

    def service_provider_attributes
      { loa3: sp_session[:loa3], service_provider_name: sp_session[:friendly_name] }
    end

    def sp_session
      session[:sp]
    end
  end
end
