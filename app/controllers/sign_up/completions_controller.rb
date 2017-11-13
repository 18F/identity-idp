module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern

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

      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to sp_session[:request_url]
      end
    end

    private

    def view_model
      SignUpCompletionsShow.new(
        loa3_requested: loa3?,
        decorated_session: decorated_session
      )
    end

    def verify_confirmed
      redirect_to verify_url if current_user.decorate.identity_not_verified?
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
  end
end
