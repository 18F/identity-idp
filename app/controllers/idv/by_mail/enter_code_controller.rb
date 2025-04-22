# frozen_string_literal: true

module Idv
  module ByMail
    class EnterCodeController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSessionConcern
      include Idv::StepIndicatorConcern
      include FraudReviewConcern
      include AbTestAnalyticsConcern
      include VerifyByMailConcern

      prepend_before_action :note_if_user_did_not_receive_letter
      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed

      def index
        analytics.idv_verify_by_mail_enter_code_visited(
          source: user_did_not_receive_letter? ? 'gpo_reminder_email' : nil,
          otp_rate_limited: rate_limiter.limited?,
          user_can_request_another_letter: gpo_verify_by_mail_policy.resend_letter_available?,
        )

        if rate_limiter.limited?
          return redirect_to idv_enter_code_rate_limited_url
        elsif pii_locked?
          return redirect_to capture_password_url
        end

        prefilled_code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?
        @gpo_verify_form = GpoVerifyForm.new(
          user: current_user,
          pii: pii,
          resolved_authn_context_result: resolved_authn_context_result,
          otp: prefilled_code,
        )
        render_enter_code_form
      end

      def pii
        Pii::Cacher.new(current_user, user_session)
          .fetch(current_user.gpo_verification_pending_profile.id)
      end

      def create
        if rate_limiter.limited?
          redirect_to idv_enter_code_rate_limited_url
          return
        end

        rate_limiter.increment!

        @gpo_verify_form = build_gpo_verify_form

        result = @gpo_verify_form.submit
        analytics.idv_verify_by_mail_enter_code_submitted(**result)

        attempts_api_tracker.idv_verify_by_mail_enter_code_submitted(
          success: result.success?,
          failure_reason: attempts_api_tracker.parse_failure_reason(result),
        )

        send_please_call_email_if_necessary(result:)

        if !result.success?
          if rate_limiter.limited?
            redirect_to idv_enter_code_rate_limited_url
          else
            render_enter_code_form
          end
        else
          prepare_for_personal_key
          redirect_to idv_personal_key_url
        end
      end

      private

      def render_enter_code_form
        @can_request_another_letter = gpo_verify_by_mail_policy.resend_letter_available?
        @user_did_not_receive_letter = user_did_not_receive_letter?
        @last_date_letter_was_sent = last_date_letter_was_sent
        render :index
      end

      def pending_in_person_enrollment?
        return false unless IdentityConfig.store.in_person_proofing_enabled
        current_user.pending_in_person_enrollment.present?
      end

      def account_not_ready_to_be_activated?
        fraud_check_failed? || pending_in_person_enrollment?
      end

      def note_if_user_did_not_receive_letter
        if !current_user && user_did_not_receive_letter?
          # Stash that the user didn't receive their letter.
          # Once the authentication process completes, they'll be redirected to complete their
          # GPO verification...
          session[:gpo_user_did_not_receive_letter] = true
        end

        if current_user && session.delete(:gpo_user_did_not_receive_letter)
          # ...and we can pick things up here.
          redirect_to idv_verify_by_mail_enter_code_path(did_not_receive_letter: 1)
        end
      end

      def prepare_for_personal_key
        unless account_not_ready_to_be_activated?
          create_user_event(:account_verified)

          UserAlerts::AlertUserAboutAccountVerified.call(
            profile: current_user.active_profile,
          )
          flash[:success] = t('account.index.verification.success')
        end

        idv_session.address_verification_mechanism = 'gpo'
        idv_session.address_confirmed!
      end

      def rate_limiter
        @rate_limiter ||= RateLimiter.new(
          user: current_user,
          rate_limit_type: :verify_gpo_key,
        )
      end

      # @param [FormResponse] result GpoVerifyForm result
      def send_please_call_email_if_necessary(result:)
        return if !result.success?

        return if result.extra[:pending_in_person_enrollment]

        return if !result.extra[:fraud_check_failed]

        return if !FeatureManagement.proofing_device_profiling_decisioning_enabled?

        current_user.send_email_to_all_addresses(:idv_please_call)
      end

      def build_gpo_verify_form
        GpoVerifyForm.new(
          user: current_user,
          pii: pii,
          resolved_authn_context_result: resolved_authn_context_result,
          otp: params_otp,
        )
      end

      def params_otp
        params.require(:gpo_verify_form).permit(:otp)[:otp]
      end

      def confirm_verification_needed
        return if current_user.gpo_verification_pending_profile?
        redirect_to account_url
      end

      def pii_locked?
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
      end

      # GPO reminder emails include an "I did not receive my letter!" link that results in
      # slightly different copy on this screen.
      def user_did_not_receive_letter?
        params[:did_not_receive_letter].present?
      end

      def last_date_letter_was_sent
        return @last_date_letter_was_sent if defined?(@last_date_letter_was_sent)

        @last_date_letter_was_sent = current_user
          .gpo_verification_pending_profile
          &.gpo_confirmation_codes
          &.pluck(:updated_at)
          &.max
      end
    end
  end
end
