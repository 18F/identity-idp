# frozen_string_literal: true

module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSessionConcern
      include RenderConditionConcern
      include StepIndicatorConcern
      include OptInHelper
      include FraudReviewConcern

      check_or_render_not_found -> { IdentityConfig.store.in_person_proofing_enabled }

      before_action :confirm_two_factor_authenticated
      before_action :handle_fraud
      before_action :confirm_in_person_session

      def show
        @is_enhanced_ipp = resolved_authn_context_result.enhanced_ipp?
        analytics.idv_in_person_ready_to_verify_visit(**opt_in_analytics_properties)
        @presenter = ReadyToVerifyPresenter.new(
          enrollment: enrollment,
          is_enhanced_ipp: @is_enhanced_ipp,
        )
      end

      private

      def confirm_in_person_session
        redirect_to account_url unless enrollment.present?
      end

      def enrollment
        current_user.pending_in_person_enrollment
      end
    end
  end
end
