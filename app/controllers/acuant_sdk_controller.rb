class AcuantSdkController < ApplicationController
  skip_before_action :verify_authenticity_token

  ACUANT_SDK_STATIC_FILES = %w[
    AcuantImageProcessingWorker.min.js
    AcuantImageProcessingWorker.wasm
  ].freeze

  def show
    # Only render files on an allowlist to prevent path traversal issues
    return render(plain: 'Not found', status: :not_found) unless requested_asset_permitted?

    SecureHeaders.append_content_security_policy_directives(
      request,
      script_src: ['\'unsafe-eval\''],
    )
    send_file(
      Rails.root.join('public', requested_asset_name),
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

  def response_content_type
    extension = File.extname(requested_asset_name)
    case extension
    when '.js'
      'application/javascript'
    when '.wasm'
      'application/wasm'
    end
  end
end
