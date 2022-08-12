class CloudFrontRequest
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

  # Regexp variables are not exactly intuitive:
  # https://ruby-doc.org/core-2.5.1/Regexp.html#class-Regexp-label-Special+global+variables
  def ip_and_port
    return nil unless viewer_address
    if viewer_address =~ /\[*\]:/ # IPv6
      {
        ip: "#{$`}]",
        port: $',
      }
    else # IPv4
      {
        ip: viewer_address.split(':').first,
        port: viewer_address.split(':').last,
      }
    end
  end
end
