module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern
    include VerifySPAttributesConcern

    before_action :confirm_two_factor_authenticated
    before_action :verify_confirmed, if: :loa3?
    before_action :apply_secure_headers_override, only: :show

    def show
      @view_model = view_model
      if show_completions_page?
        track_agency_handoff(
          Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT
        )
      else
        redirect_to account_url
      end
    end

    def update
      track_agency_handoff(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_COMPLETE
      )
      update_verified_attributes
      clear_verify_attributes_sessions
      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to sp_session[:request_url]
      end
    end

    private

    def show_completions_page?
      service_providers = sp_session[:issuer].present? || @view_model.user_has_identities?
      user_fully_authenticated? && service_providers
    end

    def view_model
      SignUpCompletionsShow.new(
        loa3_requested: loa3?,
        decorated_session: decorated_session,
        current_user: current_user,
        handoff: new_service_provider_attributes
      )
    end

    def verify_confirmed
      redirect_to idv_url if current_user.decorate.identity_not_verified?
    end

    def loa3?
      sp_session[:loa3] == true
    end

    def service_provider_attributes
      { loa3: sp_session[:loa3], service_provider_name: decorated_session.sp_name }
    end

    def decider
      CompletionsDecider.new(
        user_agent: request.user_agent, request_url: sp_session[:request_url]
      )
    end

    def sign_user_out_and_instruct_to_go_back_to_mobile_app
      sign_out
      flash[:notice] = t(
        'instructions.go_back_to_mobile_app',
        friendly_name: view_model.decorated_session.sp_name
      )
      redirect_to new_user_session_url
    end

    def track_agency_handoff(analytic)
      analytics.track_event(
        analytic,
        service_provider_attributes
      )
    end
  end
end
