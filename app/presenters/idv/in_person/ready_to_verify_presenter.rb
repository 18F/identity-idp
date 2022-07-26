module Idv
  module InPerson
    class ReadyToVerifyPresenter
      # WILLFIX: With LG-6881, confirm timezone or use deadline from enrollment response.
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']

      delegate :selected_location_details, :enrollment_code, to: :enrollment

      def initialize(enrollment:)
        @enrollment = enrollment
      end

      def formatted_due_date
        due_date.in_time_zone(USPS_SERVER_TIMEZONE).strftime(I18n.t('time.formats.event_date'))
      end

      def selected_location_hours(prefix)
        selected_location_details['hours'].each do |hours_candidate|
          hours = hours_candidate["#{prefix}Hours"]
          return localized_hours(hours) if hours
        end
      end

      def needs_proof_of_address?
        !enrollment.current_address_matches_id
      end

      private

      attr_reader :enrollment
      delegate :enrollment_code, to: :enrollment

      def barcode_image_data
        Barby::Code128C.new(enrollment_code).to_png(margin: 0, xdim: 2)
      end

      def due_date
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
