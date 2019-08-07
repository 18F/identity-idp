require 'login_gov/hostdata'

module Reports
  class OmbFitaraReport
    MOST_RECENT_MONTHS_COUNT = 2

    # Load info about our environment such as account ID and region
    def self.ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    # Generate the appropriate S3 bucket name based on the prefix from
    #   Figaro.env, the AWS account ID and region.
    # @return [String]
    def self.gen_s3_bucket_name
      "#{Figaro.env.s3_report_bucket_prefix!}.#{ec2_data.account_id}-#{ec2_data.region}"
    end

    # Reports S3 bucket
    S3_BUCKET = gen_s3_bucket_name.freeze unless Figaro.env.s3_reports_enabled! == 'false'

    # Main job entrypoint
    #
    # @return [String] If S3 uploads are enabled, return the URL of the
    #   uploaded S3 file. If they are not enabled, return the full JSON content
    #   that would have been uploaded to S3.
    #
    def call
      body = results_json

      # When S3 reports are not enabled in config, just return the JSON and
      # save it as the result on the JobRun object.
      if Figaro.env.s3_reports_enabled! == 'false'
        Rails.logger.info('Not uploading report to S3, s3_reports_enabled is false')
        return body
      end

      path = self.class.generate_s3_path
      url = upload_to_s3(path: path, body: body, content_type: 'application/json')

      latest_path = self.class.generate_s3_path(latest: true)
      upload_to_s3(path: latest_path, body: body, content_type: 'application/json')

      # Save the uploaded report URL as the job result
      url
    end

    # Generate the appropriate path to upload files in S3.
    # Paths will include the environment, a directory, the date, and a suffix.
    # @param [String] directory Next directory under environment
    # @param [String] suffix Filename suffix
    # @param [Boolean] latest If true, then use "latest" instead of the
    #   current date and year directory prefixes.
    #
    # @return [String]
    def self.generate_s3_path(directory: 'omb-fitara-report', suffix: 'omb-fitara-report.json',
                              latest: false)
      if latest
        "#{LoginGov::Hostdata.env}/#{directory}/latest.#{suffix}"
      else
        now = Time.zone.now
        "#{LoginGov::Hostdata.env}/#{directory}/#{now.year}/#{now.strftime('%F')}.#{suffix}"
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

    def results_json
      month, year = current_month
      counts = []
      MOST_RECENT_MONTHS_COUNT.times do
        counts << { month: "#{year}#{format('%02d', month)}", count: count_for_month(month, year) }
        month, year = previous_month(month, year)
      end
      { counts: counts }.to_json
    end

    def count_for_month(month, year)
      start = "#{year}-#{month}-01 00:00:00"
      month, year = next_month(month, year)
      finish = "#{year}-#{month}-01 00:00:00"
      Funnel::Registration::RangeRegisteredCount.call(start, finish)
    end

    def current_month
      today = Time.zone.today
      [today.strftime('%m').to_i, today.strftime('%Y').to_i]
    end

    def next_month(month, year)
      month += 1
      if month > 12
        month = 1
        year += 1
      end
      [month, year]
    end

    def previous_month(month, year)
      month -= 1
      if month.zero?
        month = 12
        year -= 1
      end
      [month, year]
    end
  end
end
