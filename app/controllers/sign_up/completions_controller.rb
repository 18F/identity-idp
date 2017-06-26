module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern
    include DelegatedProofingConcern

    before_action :verify_confirmed, if: :loa3?
    before_action :apply_secure_headers_override, only: :show

    def show
      @view_model = view_model

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
      redirect_to sp_session[:request_url]
    end

    private

    def view_model
      SignUpCompletionsShow.new(
        loa3_requested: loa3?,
        decorated_session: decorated_session
      )
    end

    def verify_confirmed
      if current_user.decorate.identity_not_verified? && !delegated_proofing_session?
        redirect_to verify_path
      end
    end

    def loa3?
      sp_session[:loa3] == true
    end

    def service_provider_attributes
      { loa3: sp_session[:loa3], service_provider_name: decorated_session.sp_name }
    end
  end
end
