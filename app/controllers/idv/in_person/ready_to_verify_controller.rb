module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSession
      include RenderConditionConcern
      include StepIndicatorConcern
      include OptInHelper
      include FraudReviewConcern

      check_or_render_not_found -> { IdentityConfig.store.in_person_proofing_enabled }

      before_action :in_person_handle_fraud
      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_session

      def show
        analytics.idv_in_person_ready_to_verify_visit(**opt_in_analytics_properties)
        @presenter = ReadyToVerifyPresenter.new(enrollment: enrollment)
      end

      private

      def confirm_in_person_session
        redirect_to account_url unless enrollment.present?
      end

      # in_person_handle_fraud should check if user is returning
      # if so then redirect to please call page
      # can use a spec to test it's working right proof - sign out- sign in -see call screen

      def enrollment
        current_user.pending_in_person_enrollment
      end
    end
  end
end
