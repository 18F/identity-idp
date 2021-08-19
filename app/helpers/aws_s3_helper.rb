module AwsS3Helper
  def s3_presigned_url(...)
    URI.parse(s3_object(...).presigned_url(:put, expires_in: presigned_url_expiration_in_seconds))
  end

  def s3_resource
    Aws::S3::Resource.new(region: Identity::Hostdata.aws_region)
  rescue Aws::Sigv4::Errors::MissingCredentialsError => aws_error
    Rails.logger.info "Aws Missing CredentialsError!\n" + aws_error.message
    nil
  end

  def s3_object(bucket_prefix:, keyname:)
    raise(ArgumentError, 'keyname is required') if keyname.blank?
    raise(ArgumentError, 'bucket_prefix is required') if bucket_prefix.blank?
    return if !s3_resource

    s3_resource.bucket(
      Identity::Hostdata.bucket_name("#{bucket_prefix}-#{Identity::Hostdata.env}"),
    ).object(keyname)
  end

  def presigned_url_expiration_in_seconds
    IdentityConfig.store.session_total_duration_timeout_in_minutes.minutes.seconds.to_i
  end
end
