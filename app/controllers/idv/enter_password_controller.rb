module Idv
  class EnterPasswordController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_step_allowed
    before_action :confirm_no_profile_yet
    before_action :confirm_current_password, only: [:create]

    helper_method :step_indicator_step

    rescue_from UspsInPersonProofing::Exception::RequestEnrollException,
                with: :handle_request_enroll_exception

    def new
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:encrypt, :view, true)
      analytics.idv_enter_password_visited(
        address_verification_method: idv_session.address_verification_mechanism,
        **ab_test_analytics_buckets,
      )

      @title = title
      @heading = heading

      @verify_by_mail = idv_session.verify_by_mail?
    end

    def create
      clear_future_steps!
      irs_attempts_api_tracker.idv_password_entered(success: true)

      init_profile

      flash[:success] =
        if idv_session.verify_by_mail?
          t('idv.messages.gpo.letter_on_the_way')
        else
          t('idv.messages.confirm')
        end

      redirect_to next_step

      analytics.idv_enter_password_submitted(
        success: true,
        fraud_review_pending: idv_session.profile.fraud_review_pending?,
        fraud_rejection: idv_session.profile.fraud_rejection?,
        gpo_verification_pending: idv_session.profile.gpo_verification_pending?,
        in_person_verification_pending: idv_session.profile.in_person_verification_pending?,
        deactivation_reason: idv_session.profile.deactivation_reason,
        **ab_test_analytics_buckets,
      )
      Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
        call(:verified, :view, true)
      analytics.idv_final(
        success: true,
        fraud_review_pending: idv_session.profile.fraud_review_pending?,
        fraud_rejection: idv_session.profile.fraud_rejection?,
        gpo_verification_pending: idv_session.profile.gpo_verification_pending?,
        in_person_verification_pending: idv_session.profile.in_person_verification_pending?,
        deactivation_reason: idv_session.profile.deactivation_reason,
        **ab_test_analytics_buckets,
      )

      return unless FeatureManagement.reveal_gpo_code?
      session[:last_gpo_confirmation_code] = idv_session.gpo_otp
    end

    def step_indicator_step
      return :secure_account unless idv_session.verify_by_mail?
      :get_a_letter
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :enter_password,
        controller: self,
        action: :new,
        next_steps: [:personal_key],
        preconditions: ->(idv_session:, user:) do
          idv_session.phone_or_address_step_complete?
        end,
        undo_step: ->(idv_session:, user:) {},
      )
    end

    private

    def title
      idv_session.verify_by_mail? ?
        t('titles.idv.enter_password_letter')
        : t('titles.idv.enter_password')
    end

    def heading
      if idv_session.verify_by_mail?
        t('idv.titles.session.enter_password_letter', app_name: APP_NAME)
      else
        t('idv.titles.session.enter_password', app_name: APP_NAME)
      end
    end

    def confirm_current_password
      return if valid_password?

      analytics.idv_enter_password_submitted(
        success: false,
        gpo_verification_pending: current_user.gpo_verification_pending_profile?,
        # note: this always returns false as of 8/23
        in_person_verification_pending: current_user.in_person_pending_profile?,
        fraud_review_pending: fraud_review_pending?,
        fraud_rejection: fraud_rejection?,
        **ab_test_analytics_buckets,
      )
      irs_attempts_api_tracker.idv_password_entered(success: false)

      flash[:error] = t('idv.errors.incorrect_password')
      redirect_to idv_enter_password_url
    end

    def gpo_mail_service
      @gpo_mail_service ||= Idv::GpoMail.new(current_user)
    end

    def init_profile
      idv_session.create_profile_from_applicant_with_password(password)

      if idv_session.verify_by_mail?
        current_user.send_email_to_all_addresses(:letter_reminder)
        analytics.idv_gpo_address_letter_enqueued(
          enqueued_at: Time.zone.now,
          resend: false,
          phone_step_attempts: gpo_mail_service.phone_step_attempts,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter:
            gpo_mail_service.hours_since_first_letter(first_letter_requested_at),
          **ab_test_analytics_buckets,
        )
      end

      if idv_session.profile.active?
        event, _disavowal_token = create_user_event(:account_verified)
        UserAlerts::AlertUserAboutAccountVerified.call(
          user: current_user,
          date_time: event.created_at,
          sp_name: decorated_sp_session.sp_name,
        )
      end
    end

    def first_letter_requested_at
      idv_session.profile.gpo_verification_pending_at
    end

    def valid_password?
      current_user.valid_password?(password)
    end

    def password
      params.fetch(:user, {})[:password].presence
    end

    def confirm_no_profile_yet
      # When no profile has been minted yet, keep them on this page.
      return if !idv_session.profile.present?

      # If the user is in the IPP flow, but we haven't actually managed to
      # set up their enrollment (due to exception), allow them to
      # see this page so they can re-submit and attempt to establish the
      # enrollment.
      is_ipp_and_needs_to_enroll_with_usps =
        idv_session.profile.in_person_verification_pending? &&
        idv_session.profile.in_person_enrollment&.establishing?

      return if is_ipp_and_needs_to_enroll_with_usps

      # Otherwise, move the user on
      redirect_to next_step
    end

    def next_step
      if idv_session.verify_by_mail?
        idv_letter_enqueued_url
      else
        idv_personal_key_url
      end
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
      idv_session.invalidate_personal_key!
      redirect_to idv_enter_password_url
    end
  end
end
