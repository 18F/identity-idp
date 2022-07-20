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
          enrollment_code: '2048702198804358',
          created_at: Time.zone.now,
          current_address_matches_id: true,
          selected_location_details: {
            'name' => 'BALTIMORE — Post Office™',
            'streetAddress' => '900 E FAYETTE ST RM 118',
            'city' => 'BALTIMORE',
            'state' => 'MD',
            'zip5' => '21233',
            'zip4' => '9715',
            'phone' => '555-123-6409',
            'hours' => [
              {
                'weekdayHours' => '8:30 AM - 4:30 PM',
              },
              {
                'saturdayHours' => '9:00 AM - 12:00 PM',
              },
              {
                'sundayHours' => 'Closed',
              },
            ],
          },
        )
      end
    end
  end
end
