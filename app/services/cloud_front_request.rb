class ClientRequest

  attr_accessor :client_ip, :client_port

  def initialize(request)
    @headers = request.headers
  end

  def client_ip
    # So, :think:
    # For IPv4, this is a simple .split(':').first
    # For IPv6, we need to do a bit more...
  end

  # Source IP and port for client connection to CloudFront
  def viewer_address
    @headers['CloudFront-Viewer-Address']
  end

  # HTTP version used for client connection to CloudFront
  def http_version
    @headers['CloudFront-Viewer-Http-Version']
  end

  # TLS version and ciphers used for client connection to CloudFront
  def tls_version
    @headers['CloudFront-Viewer-TLS']
  end

  # ISO country code for IP client used to connect
  def iso_country
    @headers['CloudFront-Viewer-Country']
  end

  # ISO region subcode for IP client used to connect
  def iso_region
    @headers['CloudFront-Viewer-Country-Region']
  end

end
