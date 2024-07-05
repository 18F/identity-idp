module SecurityHelpers
  def fixture(document, base64 = true)
    response = Dir.glob(File.join(File.dirname(__FILE__), 'responses', "#{document}*")).first
    if base64 && response =~ /\.xml$/
      Base64.encode64(File.read(response))
    else
      File.read(response)
    end
  end

  def valid_response_document
    @valid_response_document ||= fixture('valid_response_sha1.xml')
  end

  def invalid_x509_cert_response
    @invalid_x509_cert_response ||= fixture('invalid_x509_cert_response.xml')
  end
end
