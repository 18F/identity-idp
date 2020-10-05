module DocAuth
  class ImageUploadPresignedUrlGenerator
    include AwsS3Helper
    include OpensslHelper

    def presigned_image_upload_url(image_type:, transaction_id:)
      s3_presigned_url(
        bucket_prefix: bucket_prefix,
        keyname: "#{transaction_id}-#{image_type}",
      ).to_s
    end

    def random_gcm_params
      random_key_iv(size: 128, mode: :GCM)
    end

    def bucket_prefix
      'login-gov-idp-doc-capture'.freeze
    end
  end
end

