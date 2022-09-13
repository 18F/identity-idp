module Idv
  module InPerson
    class ReadyToVerifyPresenter
      # WILLFIX: With LG-6881, confirm timezone or use deadline from enrollment response.
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']

      attr_reader :barcode_image_url

      delegate :selected_location_details, :enrollment_code, to: :enrollment

      def initialize(enrollment:, barcode_image_url: nil)
        @enrollment = enrollment
        @barcode_image_url = barcode_image_url
      end

      def formatted_due_date
        due_date.in_time_zone(USPS_SERVER_TIMEZONE).strftime(I18n.t('time.formats.event_date'))
      end

      def selected_location_hours(prefix)
        return unless selected_location_details
        hours = selected_location_details["#{prefix}_hours"]
        return localized_hours(hours) if hours
      end

      def needs_proof_of_address?
        !enrollment.current_address_matches_id
      end

      private

      attr_reader :enrollment

      def due_date
        enrollment.enrollment_established_at ? enrollment.enrollment_established_at + IdentityConfig.store.in_person_enrollment_validity_in_days.days :
        enrollment.created_at + IdentityConfig.store.in_person_enrollment_validity_in_days.days
      end

      def localized_hours(hours)
        case hours
        when 'Closed'
          I18n.t('in_person_proofing.body.barcode.retail_hours_closed')
        else
          hours.
            split(' - '). # Hyphen
            map { |time| Time.zone.parse(time).strftime(I18n.t('time.formats.event_time')) }.
            join(' – ') # Endash
        end
      end
    end
  end
end
