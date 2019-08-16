require 'login_gov/hostdata'

module Reports
  class BaseReport
    private

    def ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    def gen_s3_bucket_name
      "#{Figaro.env.s3_report_bucket_prefix!}.#{ec2_data.account_id}-#{ec2_data.region}"
    end

    def report_timeout
      Figaro.env.report_timeout.to_i
    end

    def transaction_with_timeout
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{report_timeout}")
        yield
      end
    end

    def save_report(report_name, body)
      if Figaro.env.s3_reports_enabled! == 'false'
        logger.info('Not uploading report to S3, s3_reports_enabled is false')
        return body
      end
      upload_file_to_s3_timestamped_and_latest(report_name, body)
    end

    def upload_file_to_s3_timestamped_and_latest(report_name, body)
      latest_path, path = generate_s3_paths(report_name)
      url = upload_file_to_s3_bucket(path: path, body: body, content_type: 'application/json')
      upload_file_to_s3_bucket(path: latest_path, body: body, content_type: 'application/json')
      url
    end

    def generate_s3_paths(name)
      host_data_env = LoginGov::Hostdata.env
      latest = "#{host_data_env}/#{name}/latest.#{name}.json"
      now = Time.zone.now
      [latest, "#{host_data_env}/#{name}/#{now.year}/#{now.strftime('%F')}.#{name}.json"]
    end

    def logger
      Rails.logger
    end

    def class_name
      self.class.name
    end

    def bucket
      @bucket ||= gen_s3_bucket_name
    end

    def upload_file_to_s3_bucket(path:, body:, content_type:)
      url = "s3://#{bucket}/#{path}"
      logger.info("#{class_name}: uploading to #{url}")
      obj = Aws::S3::Resource.new.bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      logger.debug("#{class_name}: upload completed to #{url}")
      url
    end
  end
end
