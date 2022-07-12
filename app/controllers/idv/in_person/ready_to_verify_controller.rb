module Idv
  module InPerson
    class ReadyToVerifyController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.in_person_proofing_enabled }

      before_action :confirm_two_factor_authenticated
      before_action :confirm_in_person_session

      def show
        analytics.idv_in_person_ready_to_verify_visit
        @presenter = ReadyToVerifyPresenter.new(enrollment: enrollment)
      end

      private

      def confirm_in_person_session
        redirect_to account_url unless enrollment.present?
      end

      def enrollment
        InPersonEnrollment.new(
          user: current_user,
          profile: current_user.profiles.last,
          enrollment_code: '2048702198804358',
          created_at: Time.zone.now,
        )
      end
    end
  end
end
