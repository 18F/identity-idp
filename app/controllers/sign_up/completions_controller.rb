module SignUp
  class CompletionsController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_identity_verified, if: :ial2?
    before_action :apply_secure_headers_override, only: [:show, :update]
    before_action :verify_needs_completions_screen

    def show
      analytics.user_registration_agency_handoff_page_visit(
        **analytics_attributes(''),
      )
      @multiple_factors_enabled = MfaPolicy.new(current_user).multiple_factors_enabled?
      @presenter = completions_presenter
    end

    def update
      track_completion_event('agency-page')
      update_verified_attributes
      send_in_person_completion_survey
      if decider.go_back_to_mobile_app?
        sign_user_out_and_instruct_to_go_back_to_mobile_app
      else
        redirect_to(
          sp_session_request_url_with_updated_params || account_url,
          allow_other_host: true,
        )
      end
    end

    private

    def confirm_identity_verified
      redirect_to idv_url if current_user.identity_not_verified?
    end

    def verify_needs_completions_screen
      return_to_account unless needs_completion_screen_reason
    end

    def completions_presenter
      CompletionsPresenter.new(
        current_user: current_user,
        current_sp: current_sp,
        decrypted_pii: pii,
        requested_attributes: decorated_sp_session.requested_attributes.map(&:to_sym),
        ial2_requested: ial2_requested?,
        completion_context: needs_completion_screen_reason,
      )
    end

    def ial2?
      sp_session[:ial2]
    end

    def ial_max?
      sp_session[:ialmax]
    end

    def ial2_requested?
      !!(ial2? || (ial_max? && current_user.identity_verified?))
    end

    def return_to_account
      track_completion_event('account-page')
      redirect_to account_url
    end

    def decider
      CompletionsDecider.new(user_agent: request.user_agent, request_url: sp_session[:request_url])
    end

    def sign_user_out_and_instruct_to_go_back_to_mobile_app
      sign_out
      flash[:info] = t(
        'instructions.go_back_to_mobile_app',
        friendly_name: decorated_sp_session.sp_name,
      )
      redirect_to new_user_session_url
    end

    def analytics_attributes(page_occurence)
      attributes = {
        ial2: sp_session[:ial2],
        ialmax: sp_session[:ialmax],
        service_provider_name: decorated_sp_session.sp_name,
        sp_session_requested_attributes: sp_session[:requested_attributes],
        sp_request_requested_attributes: service_provider_request.requested_attributes,
        page_occurence: page_occurence,
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
        needs_completion_screen_reason: needs_completion_screen_reason,
      }

      if page_occurence.present? && DisposableDomain.disposable?(email_domain)
        attributes[:disposable_email_domain] = email_domain
      end

      attributes
    end

    def email_domain
      @email_domain ||= begin
        email_address = current_user.email_addresses.take.email
        Mail::Address.new(email_address).domain
      end
    end

    def track_completion_event(last_page)
      analytics.user_registration_complete(**analytics_attributes(last_page))
      user_session.delete(:in_account_creation_flow)
    end

    def pii
      Pii::Cacher.new(current_user, user_session).fetch(current_user.active_profile&.id) ||
        Pii::Attributes.new
    end

    def send_in_person_completion_survey
      return unless sp_session_ial == ::Idp::Constants::IAL2

      Idv::InPerson::CompletionSurveySender.send_completion_survey(
        current_user,
        current_sp.issuer,
      )
    end
  end
end
