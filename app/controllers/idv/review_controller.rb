module Idv
  class ReviewController < ApplicationController
    before_action :personal_key_confirmed

    include IdvStepConcern
    include PhoneConfirmation

    before_action :confirm_idv_steps_complete
    before_action :confirm_idv_phone_confirmed
    before_action :confirm_current_password, only: [:create]

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

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to idv_review_url
    end

    def new
      @applicant = idv_session.applicant
      @step_indicator_steps = step_indicator_steps
      analytics.track_event(Analytics::IDV_REVIEW_VISIT)

      gpo_mail_service = Idv::GpoMail.new(current_user)
      flash_now = flash.now
      if gpo_mail_service.mail_spammed?
        flash_now[:error] = t('idv.errors.mail_limit_reached')
      else
        flash_now[:success] = flash_message_content
      end
    end

    def create
      init_profile
      user_session[:need_personal_key_confirmation] = true
      redirect_to idv_confirmations_url
      analytics.track_event(Analytics::IDV_REVIEW_COMPLETE)

      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = idv_session.gpo_otp
    end

    private

    def step_indicator_steps
      steps = Idv::Flows::DocAuthFlow::STEP_INDICATOR_STEPS
      return steps if idv_session.address_verification_mechanism != 'gpo'
      steps.map do |step|
        step[:name] == :verify_phone_or_address ? step.merge(status: :pending) : step
      end
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
      idv_session.cache_encrypted_pii(password)
      idv_session.complete_session

      if idv_session.phone_confirmed?
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
      redirect_to idv_confirmations_url
    end

    def need_personal_key_confirmation?
      user_session[:need_personal_key_confirmation]
    end
  end
end
