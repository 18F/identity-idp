require 'spec_helper'
module SamlIdp
  describe SamlResponse do
    let(:reference_id) { '123' }
    let(:response_id) { 'abc' }
    let(:issuer_uri) { 'localhost' }
    let(:name_id) { 'name' }
    let(:audience_uri) { 'localhost/audience' }
    let(:saml_request_id) { 'abc123' }
    let(:saml_acs_url) { 'localhost/acs' }
    let(:algorithm) { :sha1 }
    let(:secret_key) { Default::SECRET_KEY }
    let(:x509_certificate) { Default::X509_CERTIFICATE }
    let(:xauthn) { Default::X509_CERTIFICATE }
    let(:authn_context_classref) do
      Saml::XML::Namespaces::AuthnContext::ClassRef::PASSWORD
    end
    let(:name_id_format) { 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' }
    let(:expiry) { 3 * 60 * 60 }
    let(:encryption_opts) do
      {
        cert: Default::X509_CERTIFICATE,
        block_encryption: 'aes256-cbc',
        key_transport: 'rsa-oaep-mgf1p',
      }
    end
    let(:subject_encrypted) do
      described_class.new(reference_id,
                          response_id,
                          issuer_uri,
                          name_id,
                          audience_uri,
                          saml_request_id,
                          saml_acs_url,
                          algorithm,
                          authn_context_classref,
                          name_id_format,
                          nil,
                          nil,
                          expiry,
                          encryption_opts)
    end

    subject do
      described_class.new(reference_id,
                          response_id,
                          issuer_uri,
                          name_id,
                          audience_uri,
                          saml_request_id,
                          saml_acs_url,
                          algorithm,
                          authn_context_classref,
                          name_id_format,
                          nil,
                          nil,
                          expiry)
    end

    it 'has a valid build' do
      expect(subject.build).to be_present
    end

    it 'builds encrypted' do
      expect(subject_encrypted.build).not_to match(audience_uri)
      encoded_xml = subject_encrypted.build
      resp_settings = saml_settings(saml_acs_url)
      resp_settings.private_key = Default::SECRET_KEY
      resp_settings.issuer = audience_uri
      saml_resp = OneLogin::RubySaml::Response.new(encoded_xml, settings: resp_settings)
      saml_resp.soft = false
      expect(saml_resp.is_valid?).to eq(true)
    end

    context 'with a secret key that is protected by a passphrase' do
      before do
        allow(SamlIdp.config).to receive(:secret_key).and_return(encrypted_secret_key)
        allow(SamlIdp.config).to receive(:password).and_return(encrypted_secret_key_password)
      end

      it 'builds encrypted' do
        expect(subject_encrypted.build).not_to match(audience_uri)
        encoded_xml = subject_encrypted.build
        resp_settings = saml_settings(saml_acs_url)
        resp_settings.private_key = Default::SECRET_KEY
        resp_settings.issuer = audience_uri
        saml_resp = OneLogin::RubySaml::Response.new(encoded_xml, settings: resp_settings)
        saml_resp.soft = false
        expect(saml_resp.is_valid?).to eq(true)
      end
    end

    context 'with a custom IDP x509 certificate and private key' do
      subject do
        described_class.new(reference_id,
                            response_id,
                            issuer_uri,
                            name_id,
                            audience_uri,
                            saml_request_id,
                            saml_acs_url,
                            algorithm,
                            authn_context_classref,
                            name_id_format,
                            custom_idp_x509_cert,
                            custom_idp_secret_key,
                            expiry,
                            encryption_opts)
      end

      it 'builds encrypted' do
        expect(subject.build).not_to match(audience_uri)
        encoded_xml = subject.build
        resp_settings = saml_settings(saml_acs_url)
        resp_settings.private_key = Default::SECRET_KEY
        resp_settings.issuer = audience_uri
        resp_settings.idp_cert_fingerprint = custom_idp_x509_cert_fingerprint
        saml_resp = OneLogin::RubySaml::Response.new(encoded_xml, settings: resp_settings)
        saml_resp.soft = false
        expect(saml_resp.is_valid?).to eq(true)
      end
    end
  end
end
