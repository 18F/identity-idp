module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern
    include VerifySPAttributesConcern

    before_action :confirm_two_factor_authenticated
    before_action :verify_confirmed, if: :loa3?
    before_action :apply_secure_headers_override, only: :show
    before_action :redirect_to_account_if_no_issuer
    before_action :redirect_to_sp_if_user_has_identity_for_issuer

    def show
      @view_model = view_model
      analytics.track_event(
        Analytics::USER_REGISTRATION_AGENCY_HANDOFF_PAGE_VISIT,
        analytics_attributes(''),
      )
    end

    def update
      track_completion_event('agency-page')
      handle_verified_attributes
      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to sp_session[:request_url]
      end
    end

    private

    def handle_verified_attributes
      update_verified_attributes
      clear_verify_attributes_sessions
    end

    def redirect_to_account_if_no_issuer
      redirect_to account_url if sp_session[:issuer].blank?
    end

    def redirect_to_sp_if_user_has_identity_for_issuer
      redirect_to after_sign_in_url if user_has_identity_for_issuer?(sp_session[:issuer])
    end

    def user_has_identity_for_issuer?(issuer)
      current_user.identities.where(service_provider: issuer).any?
    end

    def after_sign_in_url
      after_sign_in_path_for(current_user)
    end

    def view_model
      SignUpCompletionsShow.new(
        loa3_requested: loa3?,
        decorated_session: decorated_session,
        current_user: current_user,
        handoff: new_service_provider_attributes,
      )
    end

    def verify_confirmed
      redirect_to idv_url if current_user.decorate.identity_not_verified?
    end

    def loa3?
      sp_session[:loa3] == true
    end

    def return_to_account
      track_completion_event('account-page')
      redirect_to account_url
    end

    def decider
      CompletionsDecider.new(
        user_agent: request.user_agent, request_url: sp_session[:request_url],
      )
    end

    def sign_user_out_and_instruct_to_go_back_to_mobile_app
      sign_out
      flash[:notice] = t(
        'instructions.go_back_to_mobile_app',
        friendly_name: view_model.decorated_session.sp_name,
      )
      redirect_to new_user_session_url
    end

    def analytics_attributes(page_occurence)
      { loa3: sp_session[:loa3],
        service_provider_name: decorated_session.sp_name,
        page_occurence: page_occurence }
    end

    def track_completion_event(last_page)
      analytics.track_event(
        Analytics::USER_REGISTRATION_COMPLETE,
        analytics_attributes(last_page),
      )
      GoogleAnalyticsMeasurement.new(
        category: 'registration',
        event_action: 'completion',
        method: last_page,
        client_id: ga_cookie_client_id,
      ).send_event
    end
  end
end
