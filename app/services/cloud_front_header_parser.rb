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
    @request.headers['CloudFront-Viewer-Address']
  end
end
