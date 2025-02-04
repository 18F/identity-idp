# frozen_string_literal: true

module SignUp
  class RegistrationsController < ApplicationController
    include ApplicationHelper # for ial2_requested?
    include ThreatMetrixHelper
    include ThreatMetrixConcern

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    before_action :require_no_authentication
    before_action :redirect_if_ial2_and_idv_unavailable
    before_action :override_csp_for_threat_metrix,
                  if: -> { FeatureManagement.account_creation_device_profiling_collecting_enabled? }

    CREATE_ACCOUNT = 'create_account'

    def new
      @register_user_email_form = RegisterUserEmailForm.new(analytics:)
      analytics.user_registration_enter_email_visit
      render :new, locals: threatmetrix_variables
    end

    def create
      @register_user_email_form = RegisterUserEmailForm.new(analytics:)

      result = @register_user_email_form.submit(permitted_params.merge(request_id:))

      analytics.user_registration_email(**result)

      if result.success?
        process_successful_creation
      else
        render :new, locals: threatmetrix_variables
      end
    end

    def destroy_confirm; end

    protected

    def require_no_authentication
      return unless current_user
      redirect_to signed_in_url
    end

    def permitted_params
      params.require(:user).permit(:email, :email_language, :terms_accepted)
    end

    def process_successful_creation
      user = @register_user_email_form.user
      create_user_event(:account_created, user) unless @register_user_email_form.email_taken?

      resend_confirmation = params[:user][:resend]
      session[:email] = @register_user_email_form.email
      session[:terms_accepted] = @register_user_email_form.terms_accepted
      session[:sign_in_flow] = :create_account
      redirect_to sign_up_verify_email_url(resend: resend_confirmation)
    end

    def request_id
      sp_session[:request_id]
    end

    def redirect_if_ial2_and_idv_unavailable
      if ial2_requested? && !FeatureManagement.idv_available?
        redirect_to idv_unavailable_path(from: CREATE_ACCOUNT)
      end
    end

    def threatmetrix_variables
      return {} unless FeatureManagement.account_creation_device_profiling_collecting_enabled?
      session_id = generate_threatmetrix_session_id

      {
        threatmetrix_session_id: session_id,
        threatmetrix_javascript_urls: threatmetrix_javascript_urls(session_id),
        threatmetrix_iframe_url: threatmetrix_iframe_url(session_id),
      }
    end

    def generate_threatmetrix_session_id
      session[:sign_up_threatmetrix_session_id] ||= SecureRandom.uuid
    end
  end
end
