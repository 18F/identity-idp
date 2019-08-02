require 'login_gov/hostdata'

# these metrics are not particularly useful
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

module Reports
  class OmbFitaraReport
    MOST_RECENT_MONTHS_COUNT = 2
    S3_BUCKET = gen_s3_bucket_name.freeze unless Figaro.env.s3_reports_enabled! == 'false'

    def call
      body = results_json

      # When S3 reports are not enabled in config, just return the JSON and
      # save it as the result on the JobRun object.
      if Figaro.env.s3_reports_enabled! == 'false'
        Rails.logger.info('Not uploading report to S3, s3_reports_enabled is false')
        return body
      end

      path = self.class.generate_s3_path
      url = "s3://#{S3_BUCKET}/#{path}"
      Rails.logger.info("#{self.class.name}: uploading to #{url}")
      Aws::S3::Resource.new.bucket(S3_BUCKET).object(path).put(
        body: body, acl: 'private', content_type: 'application/json',
      )

      # Save the uploaded report URL as the job result
      url
    end

    # Load info about our environment such as account ID and region
    def self.ec2_data
      @ec2_data ||= LoginGov::Hostdata::EC2.load
    end

    def self.gen_s3_bucket_name
      "#{Figaro.env.s3_report_bucket_prefix!}.#{ec2_data.account_id}-#{ec2_data.region}"
    end

    def self.generate_s3_path(suffix: 'omb-fitara-report.json')
      now = Time.zone.now
      "#{LoginGov::Hostdata.env}/omb-fitara-report/#{now.year}/#{now.strftime('%F')}.#{suffix}"
    end

    private

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
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
