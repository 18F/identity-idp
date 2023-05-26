module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      include IdvSession
      include RenderConditionConcern
      include StepIndicatorConcern

      check_or_render_not_found -> { IdentityConfig.store.in_person_proofing_enabled }

      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_session

      def show
        analytics.idv_in_person_ready_to_verify_visit(**extra_analytics_attributes)
        @presenter = ReadyToVerifyPresenter.new(enrollment: enrollment)
      end

      private

      def confirm_in_person_session
        redirect_to account_url unless enrollment.present?
      end

      def enrollment
        current_user.pending_in_person_enrollment
      end

      def extra_analytics_attributes
        extra = {}
        bucket = session[:in_person_cta_variant]
        extra[:in_person_cta_variant] = bucket if bucket
        extra
      end
    end
  end
end
