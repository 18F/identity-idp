module Idv
  module InPerson
    class VerificationResultsEmailPresenter
      include Rails.application.routes.url_helpers

      attr_reader :enrollment, :url_options

      # update to user's time zone when out of pilot
      USPS_SERVER_TIMEZONE = ActiveSupport::TimeZone['America/New_York']

      def initialize(enrollment:, url_options:)
        @enrollment = enrollment
        @url_options = url_options
      end

      def location_name
        enrollment.selected_location_details['name']
      end

      def formatted_verified_date
        enrollment.status_updated_at.in_time_zone(USPS_SERVER_TIMEZONE).strftime(
          I18n.t('time.formats.event_date'),
        )
      end

      def service_provider
        enrollment.service_provider
      end

      def service_provider_or_app_name
        if service_provider
          service_provider.friendly_name
        else
          APP_NAME
        end
      end

      def show_cta?
        !service_provider || service_provider_homepage_url.present?
      end

      def sign_in_url
        service_provider_homepage_url || root_url
      end

      def service_provider_homepage_url
        sp_return_url_resolver.homepage_url if service_provider
      end

      private

      def sp_return_url_resolver
        SpReturnUrlResolver.new(service_provider: service_provider)
      end
    end
  end
end
