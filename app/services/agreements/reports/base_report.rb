module Agreements
  module Reports
    class BaseReport < ::Reports::BaseReport
      def gen_s3_bucket_name
        prefix = IdentityConfig.store.partner_api_bucket_prefix
        "#{prefix}.#{ec2_data.account_id}-#{ec2_data.region}"
      end

      def save_report(report_name, body, extension:)
        if !IdentityConfig.store.s3_reports_enabled
          logger.info('Not uploading report to S3, s3_reports_enabled is false')
          return body
        end
        upload_file_to_s3(report_name, body, extension)
      end

      def upload_file_to_s3(report_name, body, extension)
        s3_path = "#{report_path}#{report_name}"
        upload_file_to_s3_bucket(
          path: s3_path,
          body: body,
          content_type: Mime::Type.lookup_by_extension(extension).to_s,
        )
      end

      # The following public method should be defined in the child class
      #
      # The path to save the report to in S3. For files in the root path this
      # should be an empty string, otherwise it should end with a forward slash
      # def report_path
      #   'foo/'
      # end
    end
  end
end
