module Phones
  class AddPhoneController < ReauthnRequiredController
    include PhoneOtpRateLimitable

    before_action :confirm_two_factor_authenticated

    # GET /phone/add
    def new
      analytics.track_event(Analytics::ADD_PHONE_VISITED)
      # Set @add_phone_form for the view
      add_phone_form
    end

    # POST /phone/add
    def create
      result = add_phone_form.submit(add_phone_params)
      analytics.track_event(Analytics::ADD_PHONE_SUBMITTED, result.to_h)
      if result.success?
        start_phone_confirmation_session
        attempt_to_send_an_otp_and_handle_result
      else
        render :new
      end
    end

    # GET /phone/add/resend
    def edit
      analytics.track_event(Analytics::ADD_PHONE_RESEND_SUBMITTED)
      return redirect_to add_phone_url if session[:add_phone_confirmation_session].blank?
      session[:add_phone_confirmation_session] = add_phone_confirmation_session.regenerate_otp.to_h
      attempt_to_send_an_otp_and_handle_result
    end

    private

    def start_phone_confirmation_session
      add_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.start(
        phone: add_phone_form.phone,
        delivery_method: add_phone_form.otp_delivery_preference,
        default_phone: add_phone_form.otp_make_default_number,
      )
      session[:add_phone_confirmation_session] = add_phone_confirmation_session.to_h
    end

    def attempt_to_send_an_otp_and_handle_result
      result = otp_sender.send_otp
      analytics.track_event(Analytics::ADD_PHONE_OTP_SEND, result.to_h)
      if result.success?
        redirect_to add_phone_verification_url
      else
        handle_otp_send_failure
      end
    end

    def handle_otp_send_failure
      if otp_sender.rate_limited?
        handle_too_many_otp_sends
      elsif otp_sender.telephony_error?
        handle_telephony_error
      else
        redirect_to account_url
      end
    end

    def handle_telephony_error
      flash[:error] = otp_sender.telephony_error.friendly_message
      redirect_to add_phone_url
    end

    def otp_sender
      @otp_sender ||= PhoneConfirmation::OtpSender.new(
        user: current_user,
        phone_confirmation_session: add_phone_confirmation_session,
      )
    end

    def add_phone_form
      @add_phone_form ||= AddPhoneForm.new(current_user)
    end

    def add_phone_confirmation_session
      PhoneConfirmation::ConfirmationSession.from_h(session[:add_phone_confirmation_session])
    end

    def add_phone_params
      params.require(:add_phone_form).permit(
        :phone,
        :international_code,
        :otp_delivery_preference,
        :otp_make_default_number,
      )
    end
  end
end
