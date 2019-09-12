module Users
  class TotpSetupController < ApplicationController
    include RememberDeviceConcern
    include MfaSetupConcern
    include RememberDeviceConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_totp_setup_presenter

    def new
      return redirect_to account_url if current_user.totp_enabled?

      store_totp_secret_in_session
      track_event

      @code = new_totp_secret
      @qrcode = current_user.decorate.qrcode(new_totp_secret)
    end

    def confirm
      result = TotpSetupForm.new(current_user, new_totp_secret, params[:code].strip).submit

      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)

      if result.success?
        process_valid_code
      else
        process_invalid_code
      end
    end

    def disable
      if current_user.totp_enabled? && MfaPolicy.new(current_user).more_than_two_factors_enabled?
        process_successful_disable
      end
      redirect_to account_url
    end

    private

    def set_totp_setup_presenter
      @presenter = SetupPresenter.new(current_user, user_fully_authenticated?)
    end

    def track_event
      properties = {
        user_signed_up: MfaPolicy.new(current_user).sufficient_factors_enabled?,
        totp_secret_present: new_totp_secret.present?,
      }
      analytics.track_event(Analytics::TOTP_SETUP_VISIT, properties)
    end

    def store_totp_secret_in_session
      user_session[:new_totp_secret] = current_user.generate_totp_secret if new_totp_secret.nil?
    end

    def process_valid_code
      create_events
      mark_user_as_fully_authenticated
      save_remember_device_preference
      flash[:success] = t('notices.totp_configured') if should_show_totp_configured_message?
      redirect_to two_2fa_setup
      user_session.delete(:new_totp_secret)
    end

    def create_events
      create_user_event(:authenticator_enabled)
      Funnel::Registration::AddMfa.call(current_user.id, 'auth_app')
    end

    def should_show_totp_configured_message?
      # If the user's only MFA method is the one they just setup, then they will be redirected to
      # the mfa option screen which will show them the first MFA success message. In that case we
      # do not want to show this additional flash message here.
      MfaPolicy.new(current_user).multiple_factors_enabled?
    end

    def process_successful_disable
      analytics.track_event(Analytics::TOTP_USER_DISABLED)
      create_user_event(:authenticator_disabled)
      revoke_remember_device(current_user)
      revoke_otp_secret_key
      flash[:success] = t('notices.totp_disabled')
    end

    def revoke_otp_secret_key
      UpdateUser.new(
        user: current_user,
        attributes: { otp_secret_key: nil},
      ).call
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def user_already_has_a_personal_key?
      TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).configured?
    end

    def process_invalid_code
      flash[:error] = t('errors.invalid_totp')
      redirect_to authenticator_setup_url
    end

    def new_totp_secret
      user_session[:new_totp_secret]
    end
  end
end
