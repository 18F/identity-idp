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
      before_action :confirm_letter_sends_allowed

      def index
        @applicant = idv_session.applicant

        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer)
          .call(:usps_address, :view, true)
        idv_session.requested_letter = true
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
            idv_session.verify_info_step_complete?
          end,
          undo_step: ->(idv_session:, user:) { idv_session.address_verification_mechanism = nil },
        )
      end

      private

      def update_tracking
        Funnel::DocAuth::RegisterStep.new(current_user.id, current_sp&.issuer)
          .call(:usps_letter_sent, :update, true)

        log_letter_requested_analytics(resend: false)
        create_user_event(:gpo_mail_sent, current_user)
      end

      def confirm_mail_not_rate_limited
        redirect_to idv_enter_password_url if gpo_verify_by_mail_policy.rate_limited?
      end

      def confirm_letter_sends_allowed
        redirect_to idv_enter_password_url if !gpo_verify_by_mail_policy.send_letter_available?
      end

      def step_indicator_steps
        StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO
      end
    end
  end
end
