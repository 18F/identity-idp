module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include UserAuthenticator
    include PivCacConcern

    before_action :confirm_two_factor_authenticated
    before_action :authorize_piv_cac_setup, only: :new
    before_action :authorize_piv_cac_disable, only: :delete

    def new
      if params.key?(:token)
        process_piv_cac_setup
      else
        # add a nonce that we track for the return
        analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
        create_piv_cac_nonce
        @presenter = PivCacAuthenticationSetupPresenter.new(user_piv_cac_form)
        render :new
      end
    end

    def delete
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_DISABLED)
      current_user.update!(x509_dn_uuid: nil)
      Event.create(user_id: current_user.id, event_type: :piv_cac_disabled)
      flash[:success] = t('notices.piv_cac_disabled')
      redirect_to account_url
    end

    private

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
      redirect_to account_url
    end

    def process_invalid_submission
      create_piv_cac_nonce
      @presenter = PivCacAuthenticationSetupErrorPresenter.new(user_piv_cac_form)
      render :error
    end

    def authorize_piv_cac_disable
      redirect_to account_url unless current_user.piv_cac_enabled?
    end

    def authorize_piv_cac_setup
      redirect_to account_url if current_user.piv_cac_enabled?
    end
  end
end
