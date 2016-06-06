require 'saml_idp/assertion_builder'
require 'xmlenc'
module SamlIdp
  class EncryptedAssertionBuilder < AssertionBuilder
    attr_accessor :encryption_opts
    attr_accessor :encryption_key

    def initialize(reference_id, issuer_uri, principal, audience_uri, saml_request_id, saml_acs_url, raw_algorithm, authn_context_classref, expiry=60*60, encryption_opts=nil)
      self.reference_id = reference_id
      self.issuer_uri = issuer_uri
      self.principal = principal
      self.audience_uri = audience_uri
      self.saml_request_id = saml_request_id
      self.saml_acs_url = saml_acs_url
      self.raw_algorithm = raw_algorithm
      self.authn_context_classref = authn_context_classref
      self.expiry = expiry
      self.encryption_opts = encryption_opts
    end

    def encrypt(opts = {})
      plain_assertion = opts[:sign] ? signed : raw
      encryption_template = Nokogiri::XML::Document.parse(build_encryption_template).root
      encrypted_data = Xmlenc::EncryptedData.new(encryption_template)
      @encryption_key = encrypted_data.encrypt(plain_assertion)
      encrypted_key_node = encrypted_data.node.at_xpath(
        '//xenc:EncryptedData/ds:KeyInfo/xenc:EncryptedKey',
        Xmlenc::NAMESPACES
      )
      encrypted_key = Xmlenc::EncryptedKey.new(encrypted_key_node)
      encrypted_key.encrypt(cert.public_key, encryption_key)
      xml = Builder::XmlMarkup.new
      xml.EncryptedAssertion xmlns: Saml::XML::Namespaces::ASSERTION do |enc_assert|
        enc_assert << encrypted_data.node.to_s
      end
    end

    def cert
      if encryption_opts[:cert].is_a?(String)
        cert = OpenSSL::X509::Certificate.new(Base64.decode64(encryption_opts[:cert]))
      else
        cert = encryption_opts[:cert]
      end
    end
    private :cert

    def block_encryption_ns
      "http://www.w3.org/2001/04/xmlenc##{encryption_opts[:block_encryption]}"
    end
    private :block_encryption_ns

    def key_transport_ns
      "http://www.w3.org/2001/04/xmlenc##{encryption_opts[:key_transport]}"
    end
    private :key_transport_ns

    def cipher_algorithm
      Xmlenc::EncryptedData::ALGORITHMS[block_encryption_ns]
    end
    private :cipher_algorithm

    def build_encryption_template
      unless encryption_opts
        raise "Must set encryption_opts to build encrypted assertion"
      end
      xml = Builder::XmlMarkup.new
      xml.EncryptedData Id: 'ED', Type: 'http://www.w3.org/2001/04/xmlenc#Element',
        xmlns: 'http://www.w3.org/2001/04/xmlenc#' do |enc_data|
        enc_data.EncryptionMethod Algorithm: block_encryption_ns
        enc_data.tag! 'ds:KeyInfo', 'xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#' do |key_info|
          key_info.EncryptedKey Id: 'EK', xmlns: 'http://www.w3.org/2001/04/xmlenc#' do |enc_key|
            enc_key.EncryptionMethod Algorithm: key_transport_ns
            enc_key.tag! 'ds:KeyInfo', 'xmlns:ds' => 'http://www.w3.org/2000/09/xmldsig#' do |key_info2|
              key_info2.tag! 'ds:KeyName'
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
