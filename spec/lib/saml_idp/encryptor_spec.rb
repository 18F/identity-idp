require 'spec_helper'

require 'saml_idp/encryptor'

module SamlIdp
  describe Encryptor do
    let (:encryption_opts) do
      {   
        cert: Default::X509_CERTIFICATE,
        block_encryption: 'aes256-cbc',
        key_transport: 'rsa-oaep-mgf1p',
      }   
    end

    subject { described_class.new encryption_opts }

    it "encrypts XML" do
      raw_xml = '<foo>bar</foo>'
      encrypted_xml = subject.encrypt(raw_xml)
      expect(encrypted_xml).not_to match 'bar'
      encrypted_doc = Nokogiri::XML::Document.parse(encrypted_xml)
      encrypted_data = Xmlenc::EncryptedData.new(encrypted_doc.at_xpath('//xenc:EncryptedData', Xmlenc::NAMESPACES))
      decrypted_xml = encrypted_data.decrypt(subject.encryption_key)
      expect(decrypted_xml).to eq(raw_xml)
    end
  end
end
