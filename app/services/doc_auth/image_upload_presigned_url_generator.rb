module DocAuth
  class ImageUploadPresignedUrlGenerator
    include AwsS3Helper

    def presigned_image_upload_url(image_type:, transaction_id:)
      return nil unless Figaro.env.doc_auth_enable_presigned_s3_urls == 'true'

      s3_presigned_url(
        bucket_prefix: bucket_prefix,
        keyname: "#{transaction_id}-#{image_type}",
      ).to_s
    end

    def bucket_prefix
      'login-gov-idp-doc-capture'.freeze
    end
  end
end
