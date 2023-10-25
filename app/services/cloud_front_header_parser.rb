# frozen_string_literal: true

class CloudFrontHeaderParser
  def initialize(request)
    @request = request
  end

  def client_port
    return nil unless viewer_address
    viewer_address.split(':').last
  end

  # Source IP and port for client connection to CloudFront
  def viewer_address
    return nil unless @request&.headers
    @request.headers['CloudFront-Viewer-Address']
  end
end
