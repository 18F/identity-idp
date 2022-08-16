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
