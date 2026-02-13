# frozen_string_literal: true

class LogoUrl
  DEFAULT_LOGO = 'generic.svg'
  REGION = IdentityConfig.store.aws_region.freeze
  LINK_EXPIRY = 8.hours.freeze

  attr_reader :logo, :logo_key

  def initialize(logo, logo_key)
    @logo = logo
    @logo_key = logo_key
  end

  def url
    if FeatureManagement.logo_upload_enabled? && logo_key.present?
      s3_logo_url IdentityConfig.store.aws_logo_bucket
    else
      legacy_logo_url
    end
  end

  private

  def s3_bucket
    ActiveStorage::Service::S3Service.new(
      bucket: IdentityConfig.store.aws_logo_bucket,
      region: REGION,
    ).bucket
  end

  def s3_logo_url(bucket, region = REGION)
    "https://s3.#{region}.amazonaws.com/#{bucket}/#{logo_key}"
  end

  def legacy_logo_url
    ActionController::Base.helpers.image_path("sp-logos/#{logo || DEFAULT_LOGO}")
  rescue Propshaft::MissingAssetError
    ''
  end
end
