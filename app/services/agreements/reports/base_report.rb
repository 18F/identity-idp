module Agreements
  module Reports
    class BaseReport < ::Reports::BaseReport
      def gen_s3_bucket_name
        "#{AppConfig.env.partner_api_bucket_prefix}.#{ec2_data.account_id}-#{ec2_data.region}"
      end

      def save_report(report_name, body, path = nil)
        if AppConfig.env.s3_reports_enabled == 'false'
          logger.info('Not uploading report to S3, s3_reports_enabled is false')
          return body
        end
        upload_file_to_s3_timestamped_and_latest(report_name, body, path)
      end

      def upload_file_to_s3_timestamped_and_latest(report_name, body, path)
        latest_path, path = generate_s3_paths(report_name, path)
        url = upload_file_to_s3_bucket(path: path, body: body, content_type: 'application/json')
        upload_file_to_s3_bucket(path: latest_path, body: body, content_type: 'application/json')
        url
      end

      def generate_s3_paths(name, endpoint_path)
        latest = "#{endpoint_path}#{name}"
        now = Time.zone.now
        [latest, "archive/#{endpoint_path}#{name}/#{now.year}/#{now.strftime('%F')}.#{name}.json"]
      end
    end
  end
end
