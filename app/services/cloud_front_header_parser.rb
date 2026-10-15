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

  # JA3 TLS fingerprint for the viewer's connection to CloudFront
  def ja3_fingerprint
    return nil unless @request&.headers
    @request.headers['CloudFront-Viewer-JA3-Fingerprint']
  end

  # JA4 TLS fingerprint for the viewer's connection to CloudFront
  def ja4_fingerprint
    return nil unless @request&.headers
    @request.headers['CloudFront-Viewer-JA4-Fingerprint']
  end
end
