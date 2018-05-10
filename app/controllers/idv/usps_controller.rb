module Idv
  class UspsController < ApplicationController
    include IdvStepConcern

    before_action :confirm_mail_not_spammed

    def index
      @decorated_usps = UspsDecorator.new(usps_mail_service)
    end

    def create
      create_user_event(:usps_mail_sent, current_user)
      idv_session.address_verification_mechanism = :usps

      if current_user.decorate.needs_profile_usps_verification?
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
