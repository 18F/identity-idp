module Verify
  class UspsController < ApplicationController
    include IdvStepConcern

    before_action :confirm_mail_not_spammed

    def index
      @decorated_usps = UspsDecorator.new(usps_mail_service)
    end

    def create
      create_user_event(:usps_mail_sent, current_user)
      idv_session.address_verification_mechanism = :usps
      redirect_to verify_review_url
    end

    def usps_mail_service
      @_usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    private

    def confirm_mail_not_spammed
      redirect_to verify_review_path if idv_session.address_mechanism_chosen? &&
                                        usps_mail_service.mail_spammed?
    end
  end
end
