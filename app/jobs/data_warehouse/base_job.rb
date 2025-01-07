# frozen_string_literal: true

require 'identity/hostdata'

module DataWarehouse
  class BaseJob < ApplicationJob
    queue_as :long_running

    private

    def bucket_name
      bucket_name = IdentityConfig.store.s3_data_warehouse_bucket_prefix
      env = Identity::Hostdata.env
      aws_account_id = Identity::Hostdata.aws_account_id
      aws_region = Identity::Hostdata.aws_region
      "#{bucket_name}-#{env}-#{aws_account_id}-#{aws_region}"
    end

    def generate_s3_paths(name, extension, subname: nil, now: Time.zone.now)
      name_subdir_ext = "#{name}#{subname ? '/' : ''}#{subname}.#{extension}"
      latest = "#{name}/latest.#{name_subdir_ext}"
      [latest, "#{name}/#{now.year}/#{now.strftime('%F')}_#{name_subdir_ext}"]
    end

    def logger
      Rails.logger
    end

    def class_name
      self.class.name
    end

    def s3_client
      @s3_client ||= JobHelpers::S3Helper.new.s3_client
    end

    def upload_file_to_s3_bucket(path:, body:, content_type:, bucket: bucket_name)
      url = "s3://#{bucket}/#{path}"
      logger.info("#{class_name}: uploading to #{url}")
      obj = Aws::S3::Resource.new(client: s3_client).bucket(bucket).object(path)
      obj.put(body: body, acl: 'private', content_type: content_type)
      logger.debug("#{class_name}: upload completed to #{url}")
      url
    end

    def data_warehouse_disabled?
      !IdentityConfig.store.data_warehouse_enabled
    end
  end
end
