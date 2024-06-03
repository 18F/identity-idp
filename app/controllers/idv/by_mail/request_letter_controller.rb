# frozen_string_literal: true

module Idv
  module ByMail
    class RequestLetterController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      skip_before_action :confirm_no_pending_gpo_profile
      include Idv::StepIndicatorConcern

      before_action :confirm_mail_not_rate_limited
      before_action :confirm_step_allowed
      before_action :confirm_profile_not_too_old

      def index
        @applicant = idv_session.applicant
        @presenter = RequestLetterPresenter.new(current_user, url_options)

        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
          call(:usps_address, :view, true)
        analytics.idv_request_letter_visited(
          letter_already_sent: @presenter.resend_requested?,
        )
      end

      def create
        clear_future_steps!
        update_tracking
        idv_session.address_verification_mechanism = :gpo

        if resend_requested? && pii_locked?
          redirect_to capture_password_url
        elsif resend_requested?
          resend_letter
          flash[:success] = t('idv.messages.gpo.another_letter_on_the_way')
          redirect_to idv_letter_enqueued_url
        else
          redirect_to idv_enter_password_url
        end
      end

      def gpo_mail_service
        @gpo_mail_service ||= Idv::GpoMail.new(current_user)
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :request_letter,
          controller: self,
          action: :index,
          next_steps: [:enter_password],
          preconditions: ->(idv_session:, user:) do
            idv_session.verify_info_step_complete? || user.gpo_verification_pending_profile?
          end,
          undo_step: ->(idv_session:, user:) { idv_session.address_verification_mechanism = nil },
        )
      end

      private

      def confirm_profile_not_too_old
        redirect_to idv_path if gpo_mail_service.profile_too_old?
      end

      def update_tracking
        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
          call(:usps_letter_sent, :update, true)

        analytics.idv_gpo_address_letter_requested(
          resend: resend_requested?,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter:
            gpo_mail_service.hours_since_first_letter(first_letter_requested_at),
          phone_step_attempts: gpo_mail_service.phone_step_attempts,
          **ab_test_analytics_buckets,
        )
        create_user_event(:gpo_mail_sent, current_user)

        ProofingComponent.find_or_create_by(user: current_user).update(address_check: 'gpo_letter')
      end

      def resend_requested?
        current_user.gpo_verification_pending_profile?
      end

      def first_letter_requested_at
        current_user.gpo_verification_pending_profile&.gpo_verification_pending_at
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_enter_password_url if gpo_mail_service.rate_limited?
      end

      def resend_letter
        analytics.idv_gpo_address_letter_enqueued(
          enqueued_at: Time.zone.now,
          resend: true,
          first_letter_requested_at: first_letter_requested_at,
          hours_since_first_letter:
            gpo_mail_service.hours_since_first_letter(first_letter_requested_at),
          phone_step_attempts: gpo_mail_service.phone_step_attempts,
          **ab_test_analytics_buckets,
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
