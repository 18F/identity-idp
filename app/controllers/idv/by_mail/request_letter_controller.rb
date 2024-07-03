# frozen_string_literal: true

module Idv
  module ByMail
    class RequestLetterController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include Idv::StepIndicatorConcern
      include VerifyByMailConcern

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

        log_letter_requested_analytics(resend: false)
        create_user_event(:gpo_mail_sent, current_user)

        ProofingComponent.find_or_create_by(user: current_user).update(address_check: 'gpo_letter')
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_enter_password_url if gpo_verify_by_mail_policy.rate_limited?
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
