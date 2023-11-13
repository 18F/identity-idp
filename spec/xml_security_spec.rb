require 'spec_helper'
require 'xml_security'

module SamlIdp
  describe XMLSecurity, security: true do
    let(:document) { XMLSecurity::SignedDocument.new(Base64.decode64(response_document)) }

    let(:document_with_invalid_certificate) do
      XMLSecurity::SignedDocument.new(Base64.decode64(response_document_7))
    end

    let(:base64cert) { document.elements['//ds:X509Certificate'].text }

    describe '#validate_doc' do
      describe 'when softly validating' do
        it 'does not throw NS related exceptions' do
          expect(document.validate_doc(base64cert, true)).to be_falsey
        end

        context 'multiple validations' do
          it 'does not raise an error' do
            expect { 2.times { document.validate_doc(base64cert, true) } }.to_not raise_error
          end
        end
      end

      describe 'when validating not softly' do
        it 'throws NS related exceptions' do
          expect { document.validate_doc(base64cert, false) }.to raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError)
        end

        it 'raises Fingerprint mismatch' do
          expect { document.validate('no:fi:ng:er:pr:in:t', false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError, 'Fingerprint mismatch')
          )
        end

        it 'raises Digest mismatch' do
          expect { document.validate_doc(base64cert, false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError, 'Digest mismatch')
          )
        end

        it 'raises Key validation error' do
          response = Base64.decode64(response_document)
          response.sub!('<ds:DigestValue>pJQ7MS/ek4KRRWGmv/H43ReHYMs=</ds:DigestValue>',
                        '<ds:DigestValue>b9xsAXLsynugg3Wc1CI3kpWku+0=</ds:DigestValue>')
          document = XMLSecurity::SignedDocument.new(response)
          base64cert = document.elements['//ds:X509Certificate'].text
          expect { document.validate_doc(base64cert, false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError, 'Key validation error')
          )
        end
      end
    end

    describe '#validate' do
      describe 'errors' do
        it 'raises invalid certificates when the document ceritficate is invalid' do
          expect { document_with_invalid_certificate.validate('no:fi:ng:er:pr:in:t', false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError, 'Invalid certificate')
          )
        end

        it 'raises validation error when the X509Certificate is missing' do
          response = Base64.decode64(response_document)
          response.sub!(%r{<ds:X509Certificate>.*</ds:X509Certificate>}, '')
          document = XMLSecurity::SignedDocument.new(response)
          expect { document.validate('a fingerprint', false) }.to(
            raise_error(
              SamlIdp::XMLSecurity::SignedDocument::ValidationError,
              'Certificate element missing in response (ds:X509Certificate) and not provided in options[:cert]'
            )
          )
        end

        it 'raises a validation error when find_base64_cert returns nil' do
          response = Base64.decode64(response_document)
          document = XMLSecurity::SignedDocument.new(response)
          REXML::XPath.first(document, '//ds:X509Certificate', { 'ds' => 'http://www.w3.org/2000/09/xmldsig#' }).text = nil
          expect { document.validate('a fingerprint', false) }.to(
            raise_error(
              SamlIdp::XMLSecurity::SignedDocument::ValidationError,
              'Certificate element present in response (ds:X509Certificate) but evaluating to nil'
            )
          )
        end
      end

      describe 'Algorithms' do
        it 'validate using SHA1' do
          document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha1, false))
          expect(document.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
        end

        it 'validate using SHA256' do
          document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha256, false))
          expect(document.validate('28:74:9B:E8:1F:E8:10:9C:A8:7C:A9:C3:E3:C5:01:6C:92:1C:B4:BA')).to be_truthy
        end

        it 'validate using SHA384' do
          document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha384, false))
          expect(document.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
        end

        it 'validate using SHA512' do
          document = XMLSecurity::SignedDocument.new(fixture(:adfs_response_sha512, false))
          expect(document.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
        end
      end
    end
  end

  describe 'XmlSecurity::SignedDocument' do
    describe '#extract_inclusive_namespaces' do
      it 'support explicit namespace resolution for exclusive canonicalization' do
        response = fixture(:open_saml_response, false)
        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        expect(inclusive_namespaces).to eq(%w[xs])
      end

      it 'support implicit namespace resolution for exclusive canonicalization' do
        response = fixture(:no_signature_ns, false)
        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        expect(inclusive_namespaces).to eq(%w[#default saml ds xs xsi])
      end

      it 'return an empty list when inclusive namespace element is missing' do
        response = fixture(:no_signature_ns, false)
        response.slice! %r{<InclusiveNamespaces xmlns="http://www.w3.org/2001/10/xml-exc-c14n#" PrefixList="#default saml ds xs xsi"/>}

        document = XMLSecurity::SignedDocument.new(response)
        inclusive_namespaces = document.send(:extract_inclusive_namespaces)

        expect(inclusive_namespaces).to be_empty
      end
    end

    describe 'StarfieldTMS' do
      let(:response) { ::OneLogin::RubySaml::Response.new(fixture(:starfield_response)) }

      before do
        response.settings = ::OneLogin::RubySaml::Settings.new(
          idp_cert_fingerprint: '8D:BA:53:8E:A3:B6:F9:F1:69:6C:BB:D9:D8:BD:41:B3:AC:4F:9D:4D'
        )
      end

      it 'be able to validate a good response' do
        Timecop.freeze Time.parse('2012-11-28 17:55:00 UTC') do
          allow(response).to receive(:validate_subject_confirmation).and_return(true)
          expect(response).to be_is_valid
        end
      end

      it 'fail before response is valid' do
        Timecop.freeze Time.parse('2012-11-20 17:55:00 UTC') do
          expect(response).not_to be_is_valid
        end
      end

      it 'fail after response expires' do
        Timecop.freeze Time.parse('2012-11-30 17:55:00 UTC') do
          expect(response).not_to be_is_valid
        end
      end
    end
  end
end
