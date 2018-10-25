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

    def usps_mail_service
      @_usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    private

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
        profile: current_user.decorate.pending_profile
      )
      confirmation_maker.perform

      return unless FeatureManagement.reveal_usps_code?
      session[:last_usps_confirmation_code] = confirmation_maker.otp
    end
  end
end
