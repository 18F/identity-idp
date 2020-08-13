# rubocop:disable Metrics/ClassLength
module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PivCacConcern
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :authorize_piv_cac_disable, only: :delete
    before_action :set_piv_cac_setup_csp_form_action_uris, only: :new
    before_action :cap_piv_cac_count, only: %i[new submit_new_piv_cac]

    def new
      if params.key?(:token)
        process_piv_cac_setup
      elsif flash[:error_type].present?
        render_error
      else
        render_prompt
      end
    end

    def delete
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_DISABLED)
      remove_piv_cac
      clear_piv_cac_information
      create_user_event(:piv_cac_disabled)
      flash[:success] = t('notices.piv_cac_disabled')
      redirect_to account_url
    end

    def submit_new_piv_cac
      if good_nickname
        user_session[:piv_cac_nickname] = params[:name]
        create_piv_cac_nonce
        redirect_to piv_cac_service_url_with_redirect
      else
        flash[:error] = I18n.t('errors.piv_cac_setup.unique_name')
        render_prompt
      end
    end

    private

    def remove_piv_cac
      revoke_remember_device(current_user)
      current_user_id = current_user.id
      Db::PivCacConfiguration::Delete.call(current_user_id, params[:id].to_i)
    end

    def render_prompt
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
      @presenter = PivCacAuthenticationSetupPresenter.new(
        current_user, user_fully_authenticated?, user_piv_cac_form
      )
      render :new
    end

    def piv_cac_service_url_with_redirect
      PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: setup_piv_cac_url,
      )
    end

    def render_error
      @presenter = PivCacAuthenticationSetupErrorPresenter.new(error: flash[:error_type])
      render :error
    end

    def process_piv_cac_setup
      result = user_piv_cac_form.submit
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)
      if result.success?
        process_valid_submission
      else
        process_invalid_submission
      end
    end

    def user_piv_cac_form
      @user_piv_cac_form ||= UserPivCacSetupForm.new(
        user: current_user,
        token: params[:token],
        nonce: piv_cac_nonce,
        name: user_session[:piv_cac_nickname],
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_submission
      flash[:success] = t('notices.piv_cac_configured')
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        presented: true,
      )
      create_user_event(:piv_cac_enabled)
      Funnel::Registration::AddMfa.call(current_user.id, 'piv_cac')
      session[:needs_to_setup_piv_cac_after_sign_in] = false
      redirect_to after_sign_in_path_for(current_user)
    end

    def piv_cac_enabled?
      TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
    end

    def process_invalid_submission
      if user_piv_cac_form.name_taken
        flash.now[:error] = t('errors.piv_cac_setup.unique_name')
        render_prompt
      else
        clear_piv_cac_information
        flash[:error_type] = user_piv_cac_form.error_type
        redirect_to setup_piv_cac_url
      end
    end

    def authorize_piv_cac_disable
      return redirect_to account_url unless piv_cac_enabled? &&
                                            MfaPolicy.new(current_user).multiple_factors_enabled?
    end

    def good_nickname
      name = params[:name]
      name.present? && !PivCacConfiguration.exists?(user_id: current_user.id, name: name)
    end

    def cap_piv_cac_count
      redirect_to account_url if Figaro.env.max_piv_cac_per_account.to_i <= current_cac_count
    end

    def current_cac_count
      current_user.piv_cac_configurations.count
    end
  end
end
# rubocop:enable Metrics/ClassLength
