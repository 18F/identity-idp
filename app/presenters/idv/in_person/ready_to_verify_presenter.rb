# frozen_string_literal: true

module Idv
  module InPerson
    class ReadyToVerifyPresenter
      include ActionView::Helpers::TranslationHelper
      # WILLFIX: With LG-6881, confirm timezone or use deadline from enrollment response.
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York'].dup.freeze

      attr_reader :barcode_image_url

      delegate :selected_location_details, :enrollment_code, :enhanced_ipp?, to: :enrollment

      def initialize(enrollment:, barcode_image_url: nil, sp_name: nil)
        @enrollment = enrollment
        @barcode_image_url = barcode_image_url
        @sp_name = sp_name
      end

      def enrolled_with_passport_book?
        enrollment.document_type == InPersonEnrollment::DOCUMENT_TYPE_PASSPORT_BOOK
      end

      # Reminder is exclusive of the day the email is sent (1 less than days_to_due_date)
      def days_remaining
        enrollment.days_to_due_date - 1
      end

      def formatted_due_date
        I18n.l(
          enrollment.due_date.in_time_zone(USPS_SERVER_TIMEZONE),
          format: :event_date,
        )
      end

      def selected_location_hours(prefix)
        return unless selected_location_details
        hours = selected_location_details["#{prefix}_hours"]
        UspsInPersonProofing::EnrollmentHelper.localized_hours(hours)
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
        IdentityConfig.store.in_person_outage_message_enabled && outage_dates_present?
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

      def barcode_heading_text
        if enhanced_ipp?
          t('in_person_proofing.headings.barcode_eipp')
        elsif enrolled_with_passport_book?
          t('in_person_proofing.headings.barcode_passport')
        else
          t('in_person_proofing.headings.barcode')
        end
      end

      def state_id_heading_text
        if enhanced_ipp?
          t('in_person_proofing.process.state_id.heading_eipp')
        elsif enrolled_with_passport_book?
          t('in_person_proofing.process.passport.heading')
        else
          t('in_person_proofing.process.state_id.heading')
        end
      end

      def state_id_info
        if enhanced_ipp?
          t('in_person_proofing.process.state_id.info_eipp')
        elsif enrolled_with_passport_book?
          t('in_person_proofing.process.passport.info')
        else
          t('in_person_proofing.process.state_id.info')
        end
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

      def sp_return_url_resolver
        SpReturnUrlResolver.new(service_provider: service_provider)
      end
    end
  end
end
