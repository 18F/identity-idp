class ImageUploadPresignedUrlGenerator
  include AwsS3Helper

  def presigned_image_upload_url(image_type:, transaction_id:)
    keyname = "#{transaction_id}-#{image_type}"

    if Figaro.env.doc_auth_enable_presigned_s3_urls != 'true'
      nil
    elsif !LoginGov::Hostdata.in_datacenter?
      Rails.application.routes.url_helpers.test_fake_s3_url(key: keyname)
    else
      s3_presigned_url(
        bucket_prefix: bucket_prefix,
        keyname: keyname,
      ).to_s
    end
  end

  def bucket
    super(prefix: bucket_prefix)
  end

  def bucket_prefix
    'login-gov-idp-doc-capture'.freeze
  end
end
