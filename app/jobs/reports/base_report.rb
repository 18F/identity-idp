require 'identity/hostdata'

module Reports
  class BaseReport < ApplicationJob
    queue_as :long_running

    def self.transaction_with_timeout(rails_env = Rails.env)
      # rspec-rails's use_transactional_tests does not seem to act as expected when switching
      # connections mid-test, so we just skip for now :[
      return yield if rails_env.test?

      ActiveRecord::Base.connected_to(role: :reading, shard: :read_replica) do
        ActiveRecord::Base.transaction do
          quoted_timeout = ActiveRecord::Base.connection.quote(IdentityConfig.store.report_timeout)
          ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{quoted_timeout}")
          yield
        end
      end
    end

    private

    def public_bucket_name
      if (prefix = IdentityConfig.store.s3_report_public_bucket_prefix)
        Identity::Hostdata.bucket_name("#{prefix}-#{Identity::Hostdata.env}")
      end
    end

    def fiscal_start_date(time = Time.zone.now.beginning_of_day)
      time.change(year: time.month >= 10 ? time.year : time.year - 1, month: 10, day: 1)
    end

    def first_of_this_month
      Time.zone.now.beginning_of_month
    end

    def end_of_today
      Time.zone.now.end_of_day
    end

    def transaction_with_timeout(...)
      self.class.transaction_with_timeout(...)
    end

    def save_report(report_name, body, extension:)
      if !IdentityConfig.store.s3_reports_enabled
        logger.info('Not uploading report to S3, s3_reports_enabled is false')
        return body
      end
      upload_file_to_s3_timestamped_and_latest(report_name, body, extension)
    end

    def track_report_data_event(event, hash = {})
      write_hash_to_reports_log({ name: event, time: Time.zone.now.iso8601 }.merge(hash))
    end

    def write_hash_to_reports_log(log_hash)
      reports_logger.info(log_hash.to_json)
    end

    def reports_logger
      @reports_logger ||= ActiveSupport::Logger.new(Rails.root.join('log', 'reports.log'))
    end

    def upload_file_to_s3_timestamped_and_latest(report_name, body, extension)
      latest_path, path = generate_s3_paths(report_name, extension)
      content_type = Mime::Type.lookup_by_extension(extension).to_s
      url = upload_file_to_s3_bucket(path: path, body: body, content_type: content_type)
      upload_file_to_s3_bucket(path: latest_path, body: body, content_type: content_type)
      url
    end

    def generate_s3_paths(name, extension, now: Time.zone.now)
      host_data_env = Identity::Hostdata.env
      latest = "#{host_data_env}/#{name}/latest.#{name}.#{extension}"
      [latest, "#{host_data_env}/#{name}/#{now.year}/#{now.strftime('%F')}.#{name}.#{extension}"]
    end

    def logger
      Rails.logger
    end

    def class_name
      self.class.name
    end

    def bucket_name
      Identity::Hostdata.bucket_name(IdentityConfig.store.s3_report_bucket_prefix)
    end

    def upload_file_to_s3_bucket(path:, body:, content_type:, bucket: bucket_name)
      url = "s3://#{bucket}/#{path}"
      logger.info("#{class_name}: uploading to #{url}")
      obj = Aws::S3::Resource.new.bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      logger.debug("#{class_name}: upload completed to #{url}")
      url
    end
  end
end
