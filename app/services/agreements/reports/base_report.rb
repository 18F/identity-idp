module Agreements
  module Reports
    class BaseReport < ::Reports::BaseReport
      def gen_s3_bucket_name
        prefix = IdentityConfig.store.partner_api_bucket_prefix
        "#{prefix}.#{ec2_data.account_id}-#{ec2_data.region}"
      end

      def save_report(report_name, body, path = nil)
        if !IdentityConfig.store.s3_reports_enabled
          logger.info('Not uploading report to S3, s3_reports_enabled is false')
          return body
        end
        upload_file_to_s3(report_name, body, path)
      end

      def upload_file_to_s3(report_name, body, path)
        s3_path = "#{path}#{report_name}"
        upload_file_to_s3_bucket(path: s3_path, body: body, content_type: 'application/json')
      end
    end
  end
end
