module SecurityHelpers
  def fixture(document, base64: false, path: 'responses')
    response = Dir.glob(File.join(File.dirname(__FILE__), path, "#{document}*")).first
    File.read(response)
  end

  def valid_response_document
    @valid_response_document ||= fixture('valid_response_sha1.xml')
  end

  def invalid_x509_cert_response
    @invalid_x509_cert_response ||= fixture('invalid_x509_cert_response.xml')
  end
end
