class AcuantSdkController < ApplicationController
  skip_before_action :verify_authenticity_token

  ACUANT_SDK_STATIC_FILES = %w[
    AcuantImageProcessingService.wasm
    AcuantImageProcessingWorker.min.js
    AcuantImageProcessingWorker.wasm
    AcuantJavascriptWebSdk.min.js
  ].freeze

  def show
    # Only render files on an allowlist to prevent path traversal issues
    render plain: 'Not found', status: :not_found unless requested_asset_permitted?
    render file: "public/#{requested_asset}"
  end

  private

  def requested_asset_permitted?
    ACUANT_SDK_STATIC_FILES.include?(requested_asset)
  end

  def requested_asset
    @requested_asset ||= URI.parse(request.original_url).path.split('/').last
  end
end
