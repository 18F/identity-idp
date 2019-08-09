require 'login_gov/hostdata'

module Reports
  class BaseReport
    S3_BUCKET = gen_s3_bucket_name.freeze unless Figaro.env.s3_reports_enabled! == 'false'

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
      upload_to_s3_timestamped_and_latest(report_name, body)
    end

    def upload_to_s3_timestamped_and_latest(report_name, body)
      path = generate_s3_path(name: report_name)
      url = upload_to_s3(path: path, body: body, content_type: 'application/json')

      latest_path = generate_s3_path(name: report_name, latest: true)
      upload_to_s3(path: latest_path, body: body, content_type: 'application/json')

      url
    end

    def generate_s3_path(name:, latest: false)
      host_data_env = LoginGov::Hostdata.env
      if latest
        "#{host_data_env}/#{name}/latest.#{name}.json"
      else
        now = Time.zone.now
        "#{host_data_env}/#{name}/#{now.year}/#{now.strftime('%F')}.#{name}.json"
      end
    end

    def logger
      Rails.logger
    end

    def upload_to_s3(path:, body:, content_type:, bucket: S3_BUCKET)
      url = "s3://#{bucket}/#{path}"
      class_name = self.class.name
      logger.info("#{class_name}: uploading to #{url}")
      obj = Aws::S3::Resource.new.bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      logger.debug("#{class_name}: upload completed to #{url}")
      url
    end
  end
end
