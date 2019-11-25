module Phones
  class AddPhoneOtpVerificationController < ApplicationController
    include RememberDeviceConcern
    include PhoneOtpRateLimitable

    before_action :confirm_two_factor_authenticated
    before_action :confirm_add_phone_otp_sent
    before_action :set_code

    def new
      analytics.track_event(Analytics::ADD_PHONE_OTP_CONFIRMATION_VISITED)
      # Set @add_phone_otp_confirmation_form for the view
      add_phone_otp_verification_form
    end

    def create
      result = add_phone_otp_verification_form.submit(code: params[:code])
      analytics.track_event(Analytics::ADD_PHONE_OTP_CONFIRMATION_SUBMITTED, result.to_h)
      if result.success?
        handle_otp_verification_success
      else
        handle_otp_verification_failure
      end
    end

    private

    def confirm_add_phone_otp_sent
      return if session[:add_phone_confirmation_session].present?
      redirect_to add_phone_url
    end

    def handle_otp_verification_success
      flash[:success] = t('notices.phone_confirmed')
      send_phone_added_email
      save_remember_device_preference
      redirect_to account_url
    end

    def send_phone_added_email
      event = create_user_event_with_disavowal(:phone_added, current_user)
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.phone_added(email_address, disavowal_token: event.disavowal_token).deliver_later
      end
    end

    def handle_otp_verification_failure
      if decorated_user.locked_out?
        handle_too_many_otp_attempts
      else
        flash.now[:error] = t('two_factor_authentication.invalid_otp')
        render :new
      end
    end

    def add_phone_otp_verification_form
      @add_phone_otp_verification_form = AddPhoneOtpVerificationForm.new(
        user: current_user,
        phone_confirmation_session: add_phone_confirmation_session,
      )
    end

    def add_phone_confirmation_session
      PhoneConfirmation::ConfirmationSession.from_h(session[:add_phone_confirmation_session])
    end

    def set_code
      return unless FeatureManagement.prefill_otp_codes?
      @code = add_phone_confirmation_session.code
    end
  end
end
