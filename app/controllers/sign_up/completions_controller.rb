module SignUp
  class CompletionsController < ApplicationController
    def show
      analytics.track_event(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
        { loa3: session[:sp].try(:loa3), service_provider_name: @sp_name }
      )
    end

    def update
      redirect_to session[:saml_request_url]
    end
  end
end
