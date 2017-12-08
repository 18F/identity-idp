module Verify
  class ReviewController < ApplicationController
    include IdvStepConcern
    include PhoneConfirmation

    before_action :confirm_idv_steps_complete
    before_action :confirm_idv_phone_confirmed
    before_action :confirm_current_password, only: [:create]

    def confirm_idv_steps_complete
      return redirect_to(verify_session_url) unless idv_profile_complete?
      return redirect_to(verify_address_url) unless idv_address_complete?
    end

    def confirm_idv_phone_confirmed
      return unless idv_session.address_verification_mechanism == 'phone'
      return if idv_session.phone_confirmed?

      prompt_to_confirm_phone(
        phone: idv_session.params[:phone],
        context: 'idv'
      )
    end

    def confirm_current_password
      return if valid_password?

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to verify_review_url
    end

    def new
      @idv_params = idv_params
      analytics.track_event(Analytics::IDV_REVIEW_VISIT)

      usps_mail_service = Idv::UspsMail.new(current_user)
      flash_now = flash.now
      if usps_mail_service.mail_spammed?
        flash_now[:error] = t('idv.errors.mail_limit_reached')
      else
        flash_now[:success] = flash_message_content
      end
    end

    def create
      init_profile
      redirect_to verify_confirmations_url
      analytics.track_event(Analytics::IDV_REVIEW_COMPLETE)

      return unless FeatureManagement.reveal_usps_code?
      session[:last_usps_confirmation_code] = idv_session.usps_otp
    end

    private

    def flash_message_content
      if idv_session.address_verification_mechanism == 'usps'
        t('idv.messages.mail_sent')
      else
        phone_of_record_msg = ActionController::Base.helpers.content_tag(
          :strong, t('idv.messages.phone.phone_of_record')
        )
        t('idv.messages.review.info_verified_html', phone_message: phone_of_record_msg)
      end
    end

    def idv_profile_complete?
      idv_session.profile_confirmation == true
    end

    def idv_address_complete?
      idv_session.address_mechanism_chosen?
    end

    def init_profile
      idv_session.cache_applicant_profile_id
      idv_session.cache_encrypted_pii(current_user.user_access_key)
      idv_session.complete_session
    end

    def idv_params
      idv_session.params
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end
  end
end
