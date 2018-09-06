module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PivCacConcern

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
      current_user.update!(x509_dn_uuid: nil)
      clear_piv_cac_information
      Event.create(user_id: current_user.id, event_type: :piv_cac_disabled)
      flash[:success] = t('notices.piv_cac_disabled')
      redirect_to account_url
    end

    def redirect_to_piv_cac_service
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(piv_cac_nonce)
    end

    private

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
      current_user.mfa.two_factor_enabled?
    end

    def process_piv_cac_setup
      result = user_piv_cac_form.submit
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_ENABLED, result.to_h)
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
        nonce: piv_cac_nonce
      )
    end

    def process_valid_submission
      flash[:success] = t('notices.piv_cac_configured')
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        presented: true
      )
      redirect_to next_step
    end

    def next_step
      return account_url if current_user.mfa.phone_configurations.any?(&:mfa_enabled?)
      account_recovery_setup_url
    end

    def process_invalid_submission
      clear_piv_cac_information
      flash[:error_type] = user_piv_cac_form.error_type
      redirect_to setup_piv_cac_url
    end

    def authorize_piv_cac_disable
      redirect_to account_url unless current_user.mfa.piv_cac_configuration.mfa_enabled?
    end

    def authorize_piv_cac_setup
      redirect_to account_url if current_user.mfa.piv_cac_configuration.mfa_enabled?
    end
  end
end
