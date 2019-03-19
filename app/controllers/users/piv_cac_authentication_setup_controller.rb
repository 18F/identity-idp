module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PivCacConcern
    include AccountConfigurationConcern

    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated,
                  if: :two_factor_enabled?,
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
      attributes = { x509_dn_uuid: nil, remember_device_revoked_at: Time.zone.now }
      UpdateUser.new(user: current_user, attributes: attributes).call
    end

    def render_prompt
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
      @presenter = PivCacAuthenticationSetupPresenter.new(user_piv_cac_form)
      render :new
    end

    def render_error
      @presenter = PivCacAuthenticationSetupErrorPresenter.new(error: flash[:error_type])
      render :error
    end

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
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
      flash[:success] = t('notices.piv_cac_configured')
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        presented: true,
      )
      create_user_event(:piv_cac_enabled)
      redirect_to next_step
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
                                            MfaPolicy.new(current_user).more_than_two_factors_enabled?
    end

    def authorize_piv_cac_setup
      redirect_to account_url if piv_cac_enabled?
    end
  end
end
