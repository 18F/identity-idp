module Idv
  module InPerson
    class VerificationResultsEmailPresenter
      # update to user's time zone when out of pilot
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']

      def initialize(enrollment:)
        @enrollment = enrollment
      end

      def location_name
        @enrollment.selected_location_details['name']
      end

      def formatted_verified_date
        @enrollment.status_updated_at.in_time_zone(USPS_SERVER_TIMEZONE).strftime(
          I18n.t('time.formats.event_date'),
        )
      end
    end
  end
end
