module Idv
    module InPerson
        class VerifiedPresenter

        # update to user's time zone when out of pilot
        USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']
            def initialize(enrollment:)
                @enrollment = enrollment
            end

            def location
                @enrollment.selected_location_details["name"]
            end

            def date
                @enrollment.status_updated_at.in_time_zone(USPS_SERVER_TIMEZONE).strftime(I18n.t('time.formats.event_date'))
            end

        end
    end
end