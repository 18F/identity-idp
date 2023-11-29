module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSession
      include RenderConditionConcern
      include StepIndicatorConcern

      check_or_render_not_found -> { IdentityConfig.store.in_person_proofing_enabled }

      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_session

      def show
        analytics.idv_in_person_ready_to_verify_visit(**opt_in_analytics_properties)
        @presenter = ReadyToVerifyPresenter.new(enrollment: enrollment)
      end

      private

      def opt_in_analytics_properties
        extra = {}
        if IdentityConfig.store.in_person_proofing_opt_in_enabled
          extra = { opted_in_to_in_person_proofing: idv_session.opted_in_to_in_person_proofing }
        end
        extra
      end

      def confirm_in_person_session
        redirect_to account_url unless enrollment.present?
      end

      def enrollment
        current_user.pending_in_person_enrollment
      end
    end
  end
end
