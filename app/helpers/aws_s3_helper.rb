module AwsS3Helper
  def s3_presigned_url(...)
    URI.parse(s3_object(...).presigned_url(:put, expires_in: presigned_url_expiration_in_seconds))
  end

  def s3_resource
    Aws::S3::Resource.new(region: aws_region)
  rescue Aws::Sigv4::Errors::MissingCredentialsError => aws_error
    Rails.logger.info "Aws Missing CredentialsError!\n" + aws_error.message
    nil
  end

  def s3_object(bucket_prefix:, keyname:)
    raise(ArgumentError, 'keyname is required') if keyname.blank?
    raise(ArgumentError, 'bucket_prefix is required') if bucket_prefix.blank?
    return if !s3_resource

    s3_resource.bucket(bucket(prefix: bucket_prefix)).object(keyname)
  end

  def bucket(prefix:)
    "#{prefix}-#{host_env}.#{aws_account_id}-#{aws_region}"
  end

  def host_env
    Identity::Hostdata.env
  end

  def aws_account_id
    ec2_data.account_id
  end

  def aws_region
    ec2_data.region
  end

  def ec2_data
    Identity::Hostdata::EC2.load
  rescue Net::OpenTimeout, Errno::EHOSTDOWN, Errno::EHOSTUNREACH => e
    raise e if Identity::Hostdata.in_datacenter?

    OpenStruct.new(account_id: '123456789', region: 'us-west-2')
  end

  def presigned_url_expiration_in_seconds
    IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes.seconds.to_i
  end
end
