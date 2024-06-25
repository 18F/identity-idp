# frozen_string_literal: true

module Idv
  module ByMail
    class ResendLetterController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSessionConcern
      include Idv::StepIndicatorConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed
      before_action :confirm_mail_not_rate_limited
      before_action :confirm_profile_not_too_old

      def new
        analytics.idv_resend_letter_visited
      end

      def create
        update_tracking

        if pii_locked?
          redirect_to capture_password_url
        elsif resend_requested?
          resend_letter
          flash[:success] = t('idv.messages.gpo.another_letter_on_the_way')
          redirect_to idv_letter_enqueued_url
        end
      end

      def gpo_mail_service
        @gpo_mail_service ||= Idv::GpoMail.new(current_user)
      end

      private

      def confirm_verification_needed
        return if current_user.gpo_verification_pending_profile?
        redirect_to account_url
      end

      def confirm_profile_not_too_old
        redirect_to idv_verify_by_mail_enter_code_path if gpo_mail_service.profile_too_old?
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_verify_by_mail_enter_code_path if gpo_mail_service.rate_limited?
      end

      def update_tracking
        analytics.idv_gpo_address_letter_requested(
          resend: true,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter:
            hours_since_first_letter(first_letter_requested_at),
          phone_step_attempts: RateLimiter.new(
            user: current_user,
            rate_limit_type: :proof_address,
          ).attempts,
        )
        create_user_event(:gpo_mail_sent, current_user)
      end

      def resend_requested?
        current_user.gpo_verification_pending_profile?
      end

      def first_letter_requested_at
        current_user.gpo_verification_pending_profile&.gpo_verification_pending_at
      end

      def hours_since_first_letter(first_letter_requested_at)
        first_letter_requested_at ?
          (Time.zone.now - first_letter_requested_at).to_i.seconds.in_hours.to_i : 0
      end

      def resend_letter
        analytics.idv_gpo_address_letter_enqueued(
          enqueued_at: Time.zone.now,
          resend: true,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter:
            hours_since_first_letter(first_letter_requested_at),
          phone_step_attempts: RateLimiter.new(
            user: current_user,
            rate_limit_type: :proof_address,
          ).attempts,
        )
        confirmation_maker = confirmation_maker_perform
        send_reminder
        return unless FeatureManagement.reveal_gpo_code?
        session[:last_gpo_confirmation_code] = confirmation_maker.otp
      end

      def confirmation_maker_perform
        confirmation_maker = GpoConfirmationMaker.new(
          pii: pii,
          service_provider: current_sp,
          profile: current_user.pending_profile,
        )
        confirmation_maker.perform
        confirmation_maker
      end

      def pii
        Pii::Cacher.new(current_user, user_session).
          fetch(current_user.gpo_verification_pending_profile.id)
      end

      def send_reminder
        current_user.send_email_to_all_addresses(:verify_by_mail_letter_requested)
      end

      def pii_locked?
        !Pii::Cacher.new(current_user, user_session).exists_in_session?
      end

      def step_indicator_steps
        if in_person_proofing?
          Idv::Flows::InPersonFlow::STEP_INDICATOR_STEPS_GPO
        else
          StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO
        end
      end
    end
  end
end
