require 'login_gov/hostdata'

module Reports
  class BaseReport
    S3_BUCKET = gen_s3_bucket_name.freeze unless Figaro.env.s3_reports_enabled! == 'false'

    def self.ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    def self.gen_s3_bucket_name
      "#{Figaro.env.s3_report_bucket_prefix!}.#{ec2_data.account_id}-#{ec2_data.region}"
    end

    def self.report_timeout
      Figaro.env.report_timeout.to_i
    end

    def self.transaction_with_timeout
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{report_timeout}")
        yield
      end
    end

    def self.save_report(report_name, body)
      if Figaro.env.s3_reports_enabled! == 'false'
        Rails.logger.info('Not uploading report to S3, s3_reports_enabled is false')
        return body
      end

      path = self.class.generate_s3_path(name: report_name)
      url = upload_to_s3(path: path, body: body, content_type: 'application/json')

      latest_path = self.class.generate_s3_path(name: report_name, latest: true)
      upload_to_s3(path: latest_path, body: body, content_type: 'application/json')

      url
    end

    def self.generate_s3_path(name:, latest: false)
      if latest
        "#{LoginGov::Hostdata.env}/#{name}/latest.#{name}.json"
      else
        now = Time.zone.now
        "#{LoginGov::Hostdata.env}/#{name}/#{now.year}/#{now.strftime('%F')}.#{name}.json"
      end
    end

    private

    def upload_to_s3(path:, body:, content_type:, bucket: S3_BUCKET)
      url = "s3://#{bucket}/#{path}"
      Rails.logger.info("#{self.class.name}: uploading to #{url}")
      obj = Aws::S3::Resource.new.bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      Rails.logger.debug("#{self.class.name}: upload completed to #{url}")
      url
    end
  end
end
