module Idv
  class ReviewController < ApplicationController
    before_action :personal_key_confirmed

    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneConfirmation

    before_action :confirm_idv_steps_complete
    before_action :confirm_idv_phone_confirmed
    before_action :confirm_current_password, only: [:create]

    rescue_from UspsInPersonProofing::Exception::RequestEnrollException,
                with: :handle_request_enroll_exception

    def confirm_idv_steps_complete
      return redirect_to(idv_doc_auth_url) unless idv_profile_complete?
      return redirect_to(idv_phone_url) unless idv_address_complete?
    end

    def confirm_idv_phone_confirmed
      return unless idv_session.address_verification_mechanism == 'phone'
      return if idv_session.phone_confirmed?
      redirect_to idv_otp_verification_path
    end

    def confirm_current_password
      return if valid_password?

      analytics.idv_review_complete(success: false)
      irs_attempts_api_tracker.idv_password_entered(success: false)

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to idv_review_url
    end

    def new
      @applicant = idv_session.applicant
      analytics.idv_review_info_visited

      gpo_mail_service = Idv::GpoMail.new(current_user)
      flash_now = flash.now
      if gpo_mail_service.mail_spammed?
        flash_now[:error] = t('idv.errors.mail_limit_reached')
      else
        flash_now[:success] = flash_message_content
      end
    end

    def create
      irs_attempts_api_tracker.idv_password_entered(success: true)

      init_profile

      log_reproof_event if idv_session.profile.has_proofed_before?

      user_session[:need_personal_key_confirmation] = true

      redirect_to next_step

      analytics.idv_review_complete(success: true)
      analytics.idv_final(success: true)

      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = idv_session.gpo_otp
    end

    private

    def log_reproof_event
      irs_attempts_api_tracker.idv_reproof
    end

    def flash_message_content
      if idv_session.address_verification_mechanism != 'gpo'
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
      idv_session.create_profile_from_applicant_with_password(password)

      if idv_session.address_verification_mechanism == 'gpo'
        analytics.idv_gpo_address_letter_enqueued(enqueued_at: Time.zone.now, resend: false)
      end

      if idv_session.profile.active?
        event = create_user_event_with_disavowal(:account_verified)
        UserAlerts::AlertUserAboutAccountVerified.call(
          user: current_user,
          date_time: event.created_at,
          sp_name: decorated_session.sp_name,
          disavowal_token: event.disavowal_token,
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
      idv_personal_key_url
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
