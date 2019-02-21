module Idv
  class UspsController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_idv_needed
    before_action :confirm_user_completed_idv_profile_step
    before_action :confirm_mail_not_spammed

    def index
      @presenter = UspsPresenter.new(current_user)
    end

    def create
      create_user_event(:usps_mail_sent, current_user)
      idv_session.address_verification_mechanism = :usps

      if current_user.decorate.pending_profile_requires_verification?
        resend_letter
        redirect_to idv_come_back_later_url
      else
        redirect_to idv_review_url
      end
    end

    def update
      form_result = idv_form.submit(profile_params)
      analytics.track_event(Analytics::IDV_ADDRESS_SUBMITTED, form_result.to_h)
      if form_result.success?
        success
      else
        failure
      end
    end

    def usps_mail_service
      @_usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    private

    def success
      resend_letter
      redirect_to idv_come_back_later_url
    end

    def confirm_mail_not_spammed
      redirect_to idv_review_url if idv_session.address_mechanism_chosen? &&
                                    usps_mail_service.mail_spammed?
    end

    def confirm_user_completed_idv_profile_step
      # If the user has a pending profile, they may have completed idv in a
      # different session and need a letter resent now
      return if current_user.decorate.pending_profile_requires_verification?
      return if idv_session.profile_confirmation == true

      redirect_to idv_session_url
    end

    def resend_letter
      confirmation_maker = UspsConfirmationMaker.new(
        pii: Pii::Cacher.new(current_user, user_session).fetch,
        issuer: sp_session[:issuer],
        profile: current_user.decorate.pending_profile,
      )
      confirmation_maker.perform

      return unless FeatureManagement.reveal_usps_code?
      session[:last_usps_confirmation_code] = confirmation_maker.otp
    end

    def idv_form
      Idv::AddressForm.new(
        user: current_user,
        previous_params: idv_session.previous_profile_step_params,
      )
    end

    def profile_params
      params.require(:idv_form).permit(Idv::AddressForm::ATTRIBUTES)
    end
  end
end
