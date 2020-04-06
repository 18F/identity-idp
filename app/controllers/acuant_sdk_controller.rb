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
    send_data(
      requested_asset_data,
      type: response_content_type,
      disposition: :inline,
    )
  end

  private

  def requested_asset_permitted?
    ACUANT_SDK_STATIC_FILES.include?(requested_asset_name)
  end

  def requested_asset_name
    @requested_asset_name ||= URI.parse(request.original_url).path.split('/').last
  end

  def requested_asset_data
    File.read(
      Rails.root.join('public', requested_asset_name),
    )
  end

  def response_content_type
    if requested_asset_name.match(/\.wasm/)
      'application/wasm'
    else
      'text/javascript'
    end
  end
end
