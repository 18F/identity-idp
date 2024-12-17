# frozen_string_literal: true

module Idv
  module ByMail
    class ResendLetterController < ApplicationController
      include AvailabilityConcern
      include IdvSessionConcern
      include StepIndicatorConcern
      include VerifyByMailConcern
      include AbTestAnalyticsConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed
      before_action :confirm_resend_letter_available

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

      private

      def confirm_verification_needed
        return if current_user.gpo_verification_pending_profile?
        redirect_to account_url
      end

      def confirm_resend_letter_available
        unless gpo_verify_by_mail_policy.resend_letter_available?
          redirect_to idv_verify_by_mail_enter_code_path
        end
      end

      def update_tracking
        log_letter_requested_analytics(resend: true)
        create_user_event(:gpo_mail_sent, current_user)
      end

      def resend_requested?
        current_user.gpo_verification_pending_profile?
      end

      def resend_letter
        log_letter_enqueued_analytics(resend: true)
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
        Pii::Cacher.new(current_user, user_session)
          .fetch(current_user.gpo_verification_pending_profile.id)
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
