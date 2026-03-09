# frozen_string_literal: true

require 'active_storage'
require 'active_storage/service/s3_service'

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
    if FeatureManagement.logo_upload_enabled? && logo.present? && logo_key.present?
      s3_logo_url
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

  def s3_logo_url
    s3_bucket.object(logo_key).presigned_url(
      :get,
      expires_in: LINK_EXPIRY.to_i,
      **content_headers_for(logo),
    )
  end

  def content_headers_for(logo)
    mime_type = 'image/svg+xml' if logo.downcase.end_with? '.svg'
    mime_type ||= 'image/png'

    {
      response_content_disposition: ActionDispatch::Http::ContentDisposition.format(
        disposition: 'inline', filename: logo,
      ),
      response_content_type: mime_type,
    }
  end

  def legacy_logo_url
    ActionController::Base.helpers.image_path("sp-logos/#{logo || DEFAULT_LOGO}")
  rescue Propshaft::MissingAssetError
    ''
  end
end
