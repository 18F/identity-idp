module Idv
  class ReviewController < ApplicationController
    before_action :personal_key_confirmed

    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneConfirmation

    before_action :confirm_verify_info_step_complete
    before_action :confirm_address_step_complete
    before_action :confirm_current_password, only: [:create]

    rescue_from UspsInPersonProofing::Exception::RequestEnrollException,
                with: :handle_request_enroll_exception

    def confirm_current_password
      return if valid_password?

      analytics.idv_review_complete(
        success: false,
        fraud_review_pending: current_user.fraud_review_pending?,
        fraud_rejection: current_user.fraud_rejection?,
      )
      irs_attempts_api_tracker.idv_password_entered(success: false)

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to idv_review_url
    end

    def new
      @applicant = idv_session.applicant
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:encrypt, :view, true)
      analytics.idv_review_info_visited(address_verification_method: address_verification_method)

      gpo_mail_service = Idv::GpoMail.new(current_user)
      flash_now = flash.now
      if gpo_mail_service.mail_spammed?
        flash_now[:error] = t('idv.errors.mail_limit_reached')
      elsif idv_session.phone_confirmed?
        flash_now[:success] = t('idv.messages.review.phone_verified')
      end
    end

    def create
      irs_attempts_api_tracker.idv_password_entered(success: true)

      init_profile

      user_session[:need_personal_key_confirmation] = true

      redirect_to next_step

      analytics.idv_review_complete(
        success: true,
        fraud_review_pending: idv_session.profile.fraud_review_pending?,
        fraud_rejection: idv_session.profile.fraud_rejection?,
        gpo_verification_pending: idv_session.profile.gpo_verification_pending?,
        deactivation_reason: idv_session.profile.deactivation_reason,
      )
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:verified, :view, true)
      analytics.idv_final(
        success: true,
        fraud_review_pending: idv_session.profile.fraud_review_pending?,
        fraud_rejection: idv_session.profile.fraud_rejection?,
        deactivation_reason: idv_session.profile.deactivation_reason,
      )

      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = idv_session.gpo_otp
    end

    private

    def address_verification_method
      user_session.dig('idv', 'address_verification_mechanism')
    end

    def init_profile
      idv_session.create_profile_from_applicant_with_password(password)

      if idv_session.address_verification_mechanism == 'gpo'
        analytics.idv_gpo_address_letter_enqueued(enqueued_at: Time.zone.now, resend: false)
      end

      if idv_session.profile.active?
        event, _disavowal_token = create_user_event(:account_verified)
        UserAlerts::AlertUserAboutAccountVerified.call(
          user: current_user,
          date_time: event.created_at,
          sp_name: decorated_session.sp_name,
        )
      end
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end

    def personal_key_confirmed
      return unless current_user
      return unless current_user.active_profile.present? && need_personal_key_confirmation?
      redirect_to next_step
    end

    def need_personal_key_confirmation?
      user_session[:need_personal_key_confirmation]
    end

    def next_step
      if gpo_user_flow?
        idv_come_back_later_url
      else
        idv_personal_key_url
      end
    end

    def gpo_user_flow?
      idv_session.address_verification_mechanism == 'gpo'
    end

    def handle_request_enroll_exception(err)
      analytics.idv_in_person_usps_request_enroll_exception(
        context: context,
        enrollment_id: err.enrollment_id,
        exception_class: err.class.to_s,
        original_exception_class: err.exception_class,
        exception_message: err.message,
        reason: 'Request exception',
      )
      flash[:error] = t('idv.failure.exceptions.internal_error')
      redirect_to idv_review_url
    end
  end
end
