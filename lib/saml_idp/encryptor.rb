require 'xmlenc'
module SamlIdp
  class Encryptor
    attr_accessor :encryption_key
    attr_accessor :block_encryption
    attr_accessor :key_transport
    attr_accessor :cert

    def initialize(opts)
      self.block_encryption = opts[:block_encryption]
      self.key_transport = opts[:key_transport]
      self.cert = opts[:cert]
    end

    def encrypt(raw_xml)
      encryption_template = Nokogiri::XML::Document.parse(build_encryption_template).root
      encrypted_data = Xmlenc::EncryptedData.new(encryption_template)
      @encryption_key = encrypted_data.encrypt(raw_xml)
      encrypted_key_node = encrypted_data.node.at_xpath(
        '//xenc:EncryptedData/ds:KeyInfo/xenc:EncryptedKey',
        Xmlenc::NAMESPACES
      )
      encrypted_key = Xmlenc::EncryptedKey.new(encrypted_key_node)
      encrypted_key.encrypt(openssl_cert.public_key, encryption_key)
      xml = Builder::XmlMarkup.new
      xml.EncryptedAssertion xmlns: Saml::XML::Namespaces::ASSERTION do |enc_assert|
        enc_assert << encrypted_data.node.to_s
      end
    end

    def openssl_cert
      if cert.is_a?(String)
        @_openssl_cert ||= OpenSSL::X509::Certificate.new(Base64.decode64(cert))
      else
        @_openssl_cert ||= cert
      end
    end
    private :openssl_cert

    def block_encryption_ns
      "http://www.w3.org/2001/04/xmlenc##{block_encryption}"
    end
    private :block_encryption_ns

    def key_transport_ns
      "http://www.w3.org/2001/04/xmlenc##{key_transport}"
    end
    private :key_transport_ns

    def cipher_algorithm
      Xmlenc::EncryptedData::ALGORITHMS[block_encryption_ns]
    end
    private :cipher_algorithm

    def build_encryption_template
      xml = Builder::XmlMarkup.new
      xml.EncryptedData Id: 'ED', Type: 'http://www.w3.org/2001/04/xmlenc#Element',
        xmlns: 'http://www.w3.org/2001/04/xmlenc#' do |enc_data|
        enc_data.EncryptionMethod Algorithm: block_encryption_ns
        enc_data.tag! 'ds:KeyInfo', 'xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#' do |key_info|
          key_info.EncryptedKey Id: 'EK', xmlns: 'http://www.w3.org/2001/04/xmlenc#' do |enc_key|
            enc_key.EncryptionMethod Algorithm: key_transport_ns
            enc_key.tag! 'ds:KeyInfo', 'xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#' do |key_info2|
              key_info2.tag! 'ds:X509Data' do |x509_data|
                x509_data.tag! 'ds:X509Certificate' do |x509_cert|
                  x509_cert << cert.to_s.gsub(/-+(BEGIN|END) CERTIFICATE-+/, '')
                end
              end
            end
            enc_key.CipherData do |cipher_data|
              cipher_data.CipherValue
            end
            enc_key.ReferenceList do |ref_list|
              ref_list.DataReference URI: 'ED'
            end
          end
        end
        enc_data.CipherData do |cipher_data|
          cipher_data.CipherValue
        end
      end
    end
    private :build_encryption_template
  end
end
