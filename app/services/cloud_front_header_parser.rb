class CloudFrontHeaderParser
  def initialize(request)
    @request = request
  end

  def client_ip
    addr = ip_and_port
    return nil unless addr
    addr[:ip]
  end

  def client_port
    addr = ip_and_port
    return nil unless addr
    addr[:port]
  end

  # Source IP and port for client connection to CloudFront
  def viewer_address
    @request.get_header 'CloudFront-Viewer-Address'
  end

  # HTTP version used for client connection to CloudFront
  def http_version
    @request.get_header 'CloudFront-Viewer-Http-Version'
  end

  # TLS version and ciphers used for client connection to CloudFront
  def tls_version
    @request.get_header 'CloudFront-Viewer-TLS'
  end

  # ISO country code for IP client used to connect
  def iso_country
    @request.get_header 'CloudFront-Viewer-Country'
  end

  # ISO region subcode for IP client used to connect
  def iso_region
    @request.get_header 'CloudFront-Viewer-Country-Region'
  end

  private

  def ip_and_port
    return nil unless viewer_address
    *address_parts, port = viewer_address.split(':')
    ip = address_parts.join(':')
    {
      ip: ip,
      port: port,
    }
  end
end
