module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PivCacConcern
    include MfaSetupConcern
    include RememberDeviceConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup,
                  except: :redirect_to_piv_cac_service
    before_action :authorize_piv_cac_setup, only: :new
    before_action :authorize_piv_cac_disable, only: :delete

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

    def redirect_to_piv_cac_service
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(piv_cac_nonce)
    end

    private

    def remove_piv_cac
      revoke_remember_device(current_user)
      attributes = { x509_dn_uuid: nil }
      UpdateUser.new(user: current_user, attributes: attributes).call
    end

    def render_prompt
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
      @presenter = PivCacAuthenticationSetupPresenter.new(
        current_user, user_fully_authenticated?, user_piv_cac_form
      )
      render :new
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
      )
    end

    def process_valid_submission
      flash[:success] = t('notices.piv_cac_configured') if should_show_success_message?
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        presented: true,
      )
      create_user_event(:piv_cac_enabled)
      Funnel::Registration::AddMfa.call(current_user.id, 'piv_cac')
      redirect_to next_step
    end

    def next_step
      if MfaPolicy.new(current_user).sufficient_factors_enabled?
        account_url
      else
        two_factor_options_success_url
      end
    end

    def should_show_success_message?
      MfaPolicy.new(current_user).multiple_factors_enabled?
    end

    def piv_cac_enabled?
      TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
    end

    def process_invalid_submission
      clear_piv_cac_information
      flash[:error_type] = user_piv_cac_form.error_type
      redirect_to setup_piv_cac_url
    end

    def authorize_piv_cac_disable
      return redirect_to account_url unless piv_cac_enabled? &&
                                            MfaPolicy.new(current_user).
                                            more_than_two_factors_enabled?
    end

    def authorize_piv_cac_setup
      redirect_to account_url if piv_cac_enabled?
    end
  end
end
