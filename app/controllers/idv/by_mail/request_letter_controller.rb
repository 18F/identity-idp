# frozen_string_literal: true

module Idv
  module ByMail
    class RequestLetterController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include Idv::StepIndicatorConcern

      before_action :confirm_mail_not_rate_limited
      before_action :confirm_step_allowed

      def index
        @applicant = idv_session.applicant

        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
          call(:usps_address, :view, true)
        analytics.idv_request_letter_visited
      end

      def create
        clear_future_steps!
        update_tracking
        idv_session.address_verification_mechanism = :gpo
        redirect_to idv_enter_password_url
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

      def update_tracking
        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer).
          call(:usps_letter_sent, :update, true)

        analytics.idv_gpo_address_letter_requested(
          resend: false,
          first_letter_requested_at: nil,
          hours_since_first_letter: 0,
          phone_step_attempts: RateLimiter.new(
            user: current_user,
            rate_limit_type: :proof_address,
          ).attempts,
          **ab_test_analytics_buckets,
        )
        create_user_event(:gpo_mail_sent, current_user)

        ProofingComponent.find_or_create_by(user: current_user).update(address_check: 'gpo_letter')
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_enter_password_url if gpo_mail_service.rate_limited?
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
