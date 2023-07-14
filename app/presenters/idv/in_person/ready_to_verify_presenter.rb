module Idv
  module InPerson
    class ReadyToVerifyPresenter
      # WILLFIX: With LG-6881, confirm timezone or use deadline from enrollment response.
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']

      attr_reader :barcode_image_url

      delegate :selected_location_details, :enrollment_code, to: :enrollment

      def initialize(enrollment:, barcode_image_url: nil, sp_name: nil)
        @enrollment = enrollment
        @barcode_image_url = barcode_image_url
        @sp_name = sp_name
      end

      # Reminder is exclusive of the day the email is sent (1 less than days_to_due_date)
      def days_remaining
        enrollment.days_to_due_date - 1
      end

      def formatted_due_date
        enrollment.due_date.in_time_zone(USPS_SERVER_TIMEZONE).
          strftime(I18n.t('time.formats.event_date'))
      end

      def selected_location_hours(prefix)
        return unless selected_location_details
        hours = selected_location_details["#{prefix}_hours"]
        return localized_hours(hours) if hours
      end

      def needs_proof_of_address?
        !(enrollment.current_address_matches_id || enrollment.capture_secondary_id_enabled)
      end

      def service_provider
        enrollment.service_provider
      end

      def sp_name
        service_provider ? service_provider.friendly_name : APP_NAME
      end

      def service_provider_homepage_url
        sp_return_url_resolver.homepage_url if service_provider
      end

      def outage_message_enabled?
        IdentityConfig.store.in_person_outage_message_enabled == true && outage_dates_present?
      end

      def formatted_outage_expected_update_date
        format_outage_date(outage_expected_update_date)
      end

      def formatted_outage_emailed_by_date
        format_outage_date(outage_emailed_by_date)
      end

      def outage_dates_present?
        outage_expected_update_date.present? && outage_emailed_by_date.present?
        formatted_outage_expected_update_date
        formatted_outage_emailed_by_date
        true
      rescue
        false
      end

      private

      attr_reader :enrollment

      def outage_expected_update_date
        IdentityConfig.store.in_person_outage_expected_update_date
      end

      def outage_emailed_by_date
        IdentityConfig.store.in_person_outage_emailed_by_date
      end

      def format_outage_date(date)
        I18n.l(date.to_date, format: :short)
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

      def sp_return_url_resolver
        SpReturnUrlResolver.new(service_provider: service_provider)
      end
    end
  end
end
