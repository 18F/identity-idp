module JobHelpers
  class S3Helper
    def s3_url?(url)
      URI.parse(url).host.split('.').include?('s3')
    end

    def download(url)
      uri = URI.parse(url)
      if uri.host.start_with?('s3.')
        _, bucket, key = uri.path.split('/')
      else
        bucket, *_rest = uri.host.split('.')
        _, key, *_rest = uri.path.split('/')
      end
      resp = s3_client.get_object(bucket: bucket, key: key)
      resp.body.read.b
    end

    def s3_client
      require 'aws-sdk-s3'

      @s3_client ||= Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
        compute_checksums: false,
      )
    end

    def attempts_bucket_name
      IdentityConfig.store.irs_attempt_api_bucket_name
    end

    def attempts_s3_write_enabled
      (attempts_bucket_name && attempts_bucket_name != 'default-placeholder')
    end

    def attempts_s3_serve_enabled
      IdentityConfig.store.irs_attempt_api_aws_s3_enabled && attempts_s3_write_enabled
    end
  end
end
