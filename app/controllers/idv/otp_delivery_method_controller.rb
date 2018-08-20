module Idv
  class OtpDeliveryMethodController < ApplicationController
    include IdvSession
    include TwoFactorAuthenticatable

    # Skip TwoFactorAuthenticatable before action that depends on MFA contexts
    # to redirect to account url for signed in users. This controller does not
    # use or maintain MFA contexts
    skip_before_action :check_already_authenticated

    before_action :confirm_two_factor_authenticated
    before_action :confirm_phone_step_complete
    before_action :handle_locked_out_user
    before_action :confirm_step_needed
    before_action :set_otp_delivery_method_presenter
    before_action :set_otp_delivery_selection_form

    def new; end

    def create
      result = @otp_delivery_selection_form.submit(otp_delivery_selection_params)
      # TODO: analytics
      return render(:new) unless result.success?
      send_phone_confirmation_otp
    end

    private

    def confirm_phone_step_complete
      redirect_to idv_review_url if idv_session.vendor_phone_confirmation != true
    end

    def confirm_step_needed
      redirect_to idv_review_url if idv_session.address_verification_mechanism != 'phone' ||
                                    idv_session.user_phone_confirmation == true
    end

    def handle_locked_out_user
      reset_attempt_count_if_user_no_longer_locked_out
      return unless decorated_user.locked_out?
      handle_second_factor_locked_user 'generic'
      false
    end

    def otp_delivery_selection_params
      params.require(:otp_delivery_selection_form).permit(
        :otp_delivery_preference
      )
    end

    def set_otp_delivery_method_presenter
      @set_otp_delivery_method_presenter = Idv::OtpDeliveryMethodPresenter.new(
        idv_session.params[:phone]
      )
    end

    def set_otp_delivery_selection_form
      @otp_delivery_selection_form = OtpDeliverySelectionForm.new(
        current_user,
        idv_session.params[:phone],
        'idv'
      )
    end

    def send_phone_confirmation_otp
      save_delivery_preference_in_session
      send_phone_confirmation_otp_service.call
      # TODO: analytics
      if send_phone_confirmation_otp_service.user_locked_out?
        handle_too_many_otp_sends
      else
        redirect_to idv_otp_verification_url
      end
    end

    def save_delivery_preference_in_session
      idv_session.phone_confirmation_otp_delivery_method =
        @otp_delivery_selection_form.otp_delivery_preference
    end

    def send_phone_confirmation_otp_service
      @send_phone_confirmation_otp_service ||= Idv::SendPhoneConfirmationOtp.new(
        user: current_user,
        idv_session: idv_session,
        locale: user_locale
      )
    end

    def user_locale
      available_locales = PhoneVerification::AVAILABLE_LOCALES
      http_accept_language.language_region_compatible_from(available_locales)
    end
  end
end
