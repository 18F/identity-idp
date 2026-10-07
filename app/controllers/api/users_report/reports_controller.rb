# frozen_string_literal: true

module Api
  module UsersReport
    class ReportsController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.users_report_api_enabled }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      skip_before_action :verify_authenticity_token
      # Report config is resolved first so that server misconfiguration (an issuer
      # mapping to zero or multiple report configs) surfaces as a 500 and takes
      # precedence over authentication and validation failures.
      before_action :resolve_report_config
      before_action :authenticate_client
      before_action :validate_hourstamp

      rescue_from ::UsersReport::ReportConfigResolver::ConfigurationError,
                  with: :render_server_error

      def show
        csv_body = s3_client.get_object(bucket: bucket_name, key: report_key).body.read

        track_request(success: true, status: 200)

        send_data(
          csv_body,
          filename: "#{report_name}_#{hourstamp}.csv",
          type: 'text/csv',
          disposition: 'attachment',
        )
      rescue Aws::S3::Errors::NoSuchKey
        track_request(success: false, status: 404, failure_type: :not_found)
        render json: { error: 'CSV file is not available' }, status: :not_found
      rescue Aws::S3::Errors::ServiceError => e
        render_server_error(e)
      end

      private

      def resolve_report_config
        # A missing/malformed Authorization header has no issuer to resolve
        return if header_issuer.blank?

        report_config
      end

      def authenticate_client
        return if request_token.valid?

        track_request(success: false, status: 401, failure_type: :authorization)
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end

      def validate_hourstamp
        return if parsed_hour.present?

        track_request(success: false, status: 400, failure_type: :bad_request)
        render json: { error: 'hourstamp must be formatted as YYYYMMDDHH in UTC' },
               status: :bad_request
      end

      def parsed_hour
        return @parsed_hour if defined?(@parsed_hour)

        @parsed_hour = begin
          value = params[:hourstamp].to_s
          if /\A\d{10}\z/.match?(value)
            Time.use_zone('UTC') do
              parsed = Time.zone.strptime(value, '%Y%m%d%H')
              parsed if parsed.strftime('%Y%m%d%H') == value
            end
          end
        rescue ArgumentError
          nil
        end
      end

      def hourstamp
        @hourstamp ||= params[:hourstamp]
      end

      def request_token
        @request_token ||= ::UsersReport::RequestTokenValidator.new(request.authorization)
      end

      def s3_client
        @s3_client ||= JobHelpers::S3Helper.new.s3_client
      end

      def bucket_name
        @bucket_name ||= Identity::Hostdata.bucket_name(IdentityConfig.store.s3_report_bucket_prefix)
      end

      def report_key
        time = parsed_hour
        "#{Identity::Hostdata.env}/#{report_name}/#{time.year}/#{time.strftime('%F.%H')}.csv"
      end

      def report_name
        @report_name ||=
          "#{report_config.fetch('agency_abbreviation').downcase}_proofing_events_by_uuid"
      end

      def report_config
        @report_config ||=
          ::UsersReport::ReportConfigResolver.new(header_issuer).report_config
      end

      def header_issuer
        return @header_issuer if defined?(@header_issuer)

        @header_issuer =
          case request.authorization.to_s.split(' ', 3)
          in ['Bearer', String => issuer, String]
            issuer
          else
            nil
          end
      end

      def render_server_error(exception)
        NewRelic::Agent.notice_error(exception)
        track_request(success: false, status: 500, failure_type: :server_error)
        render json: { error: 'An unexpected error was encountered' },
               status: :internal_server_error
      end

      def track_request(success:, status:, failure_type: nil)
        analytics.users_report_api_requested(
          issuer: header_issuer,
          hourstamp:,
          agency_abbreviation: @report_config&.dig('agency_abbreviation'),
          success:,
          status:,
          failure_type:,
        )
      end
    end
  end
end
