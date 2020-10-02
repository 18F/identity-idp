module AwsHelper
  def presigned_image_upload_url(image_type:, transaction_id:)
    s3_presigned_url(bucket_prefix: "login-gov-idp-doc-capture", keyname: "#{transaction_id}-#{image_type}")
  end
  
  def s3_presigned_url(bucket_prefix:, keyname:)
    raise ArgumentError.new('keyname is required') if keyname.nil?
    return nil unless s3_resource
    
    obj = s3_resource.bucket(bucket(prefix: bucket_prefix)).object(keyname)
    URI.parse(obj.presigned_url(:put))
  end

  def s3_resource
    Aws::S3::Resource.new(region: aws_region)
  rescue Aws::Sigv4::Errors::MissingCredentialsError => aws_error
    Rails.logger.info "Aws Missing CredentialsError!\n" + aws_error.message
    nil
  end

  def bucket(prefix:)
    "#{prefix}-#{host_env}.#{aws_account_id}-#{aws_region}"
  end

  def host_env
    LoginGov::Hostdata.env
  end

  def aws_account_id
    ec2_data.account_id
  end

  def aws_region
    ec2_data.region
  end

  def ec2_data
    @ec2_data ||= LoginGov::Hostdata::EC2.load

  rescue Net::OpenTimeout => e
    if LoginGov::Hostdata.in_datacenter?
      raise e
    else
      # Don't fail in local dev env
      OpenStruct.new(account_id: 123456789, region: 'us-west-2')
    end
  end
end
