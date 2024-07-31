require 'spec_helper'
require 'xml_security'

module SamlIdp
  describe 'XmlSecurity::SignedDocument' do
    let(:xml_string) { fixture('valid_response_sha1.xml', false) }
    let(:ds_namespace) { { 'ds' => 'http://www.w3.org/2000/09/xmldsig#' } }

    subject do
      XMLSecurity::SignedDocument.new(xml_string)
    end

    let(:base64cert) do
      subject.document.at_xpath('//ds:X509Certificate', ds_namespace).text
    end

    describe '#validate_doc' do
      describe 'when softly validating' do
        it 'does not throw NS related exceptions' do
          expect(subject.validate_doc(base64cert, true)).to be_falsey
        end

        context 'multiple validations' do
          it 'does not raise an error' do
            expect { 2.times { subject.validate_doc(base64cert, true) } }.not_to raise_error
          end
        end
      end

      describe 'when validating not softly' do
        it 'throws NS related exceptions' do
          expect do
            subject.validate_doc(base64cert,
                                  false)
          end.to raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError)
        end

        it 'raises Fingerprint mismatch' do
          expect { subject.validate('no:fi:ng:er:pr:in:t', false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError,
                        'Fingerprint mismatch')
          )
        end

        it 'raises Digest mismatch' do
          expect { subject.validate_doc(base64cert, false) }.to(
            raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError, 'Digest mismatch')
          )
        end

        context 'Key validation error' do
          let(:xml_string) do
            xml = fixture('valid_response_sha1.xml', false)
            xml.sub!('<ds:DigestValue>pJQ7MS/ek4KRRWGmv/H43ReHYMs=</ds:DigestValue>',
              '<ds:DigestValue>b9xsAXLsynugg3Wc1CI3kpWku+0=</ds:DigestValue>')
          end

          it 'raises Key validation error' do
            expect { subject.validate_doc(base64cert, false) }.to(
              raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError,
                          'Key validation error')
            )
          end
        end
      end

      describe 'options[:digest_method_fix_enabled]' do
        let(:xml_string) do
          SamlIdp::Request.from_deflated_request(
            signed_auth_request
          ).raw_xml
        end

        let(:digest_method_fix_enabled) { true }
        let(:options) { { digest_method_fix_enabled: } }

        context 'digest_method_fix_enabled is set to true' do
          it 'validates the doc successfully' do
            expect(subject.validate_doc(base64cert, true, options)).to be true
          end
        end

        context 'digest_method_fix_enabled is set to false' do
          let(:digest_method_fix_enabled) { false }

          it 'validates the doc successfully' do
            expect(subject.validate_doc(base64cert, true, options)).to be true
          end
        end
      end
    end

    describe '#validate' do
      describe 'errors' do
        context 'invalid document certificate' do
          let(:xml_string) { fixture('invalid_x509_cert_response.xml', false) }

          it 'raises invalid certificates when the document certificate is invalid' do
            expect { subject.validate('no:fi:ng:er:pr:in:t', false) }.to(
              raise_error(SamlIdp::XMLSecurity::SignedDocument::ValidationError,
                          'Invalid certificate')
            )
          end
        end

        context 'x509Certicate is missing' do
          let(:xml_string) do
            xml = fixture('valid_response_sha1.xml', false)
            xml.sub!(%r{<ds:X509Certificate>.*</ds:X509Certificate>}, '')
          end

          it 'raises validation error when the X509Certificate is missing' do
            expect { subject.validate('a fingerprint', false) }.to(
              raise_error(
                SamlIdp::XMLSecurity::SignedDocument::ValidationError,
                'Certificate element missing in response (ds:X509Certificate) and not provided in options[:cert]'
              )
            )
          end
        end

        context 'find_base_64 returns nil' do
          let(:xml_string) do
            xml = fixture('valid_response_sha1.xml', false)
            xml.sub!(%r{<ds:X509Certificate>.*</ds:X509Certificate>}, '<ds:X509Certificate></ds:X509Certificate>')
          end

          it 'raises a validation error when find_base64_cert returns nil' do
            expect { subject.validate('a fingerprint', false) }.to(
              raise_error(
                SamlIdp::XMLSecurity::SignedDocument::ValidationError,
                'Certificate element present in response (ds:X509Certificate) but evaluating to nil'
              )
            )
          end
        end
      end

      describe '#digest_method_algorithm' do
        let(:xml_string) { fixture(:no_ds_namespace_request, false) }

        let(:sig_element) do
          subject.document.at_xpath('//ds:Signature | //Signature', ds_namespace)
        end

        let(:ref) do
          sig_element.at_xpath('//ds:Reference | //Reference', ds_namespace)
        end

        context 'digest_method_fix_enabled is true' do
          let(:digest_method_fix_enabled) { true }

          context 'document does not have ds namespace for Signature elements' do
            it 'returns the value in the DigestMethod node' do
              expect(subject.send(
                       :digest_method_algorithm,
                       ref,
                       digest_method_fix_enabled
                     )).to eq OpenSSL::Digest::SHA256
            end

            describe 'when the DigestMethod node does not exist' do
              before do
                ref.at_xpath('//ds:DigestMethod | //DigestMethod', ds_namespace).remove
              end

              it 'returns the default algorithm type' do
                expect(subject.send(
                         :digest_method_algorithm,
                         ref,
                         digest_method_fix_enabled
                       )).to eq OpenSSL::Digest::SHA1
              end
            end
          end

          context 'document does have ds namespace for Signature elements' do
            let(:xml_string) do
              SamlIdp::Request.from_deflated_request(
                signed_auth_request
              ).raw_xml
            end

            it 'returns the value in the DigestMethod node' do
              expect(subject.send(
                       :digest_method_algorithm,
                       ref,
                       digest_method_fix_enabled
                     )).to eq OpenSSL::Digest::SHA256
            end

            describe 'when the DigestMethod node does not exist' do
              before do
                ref.at_xpath('//ds:DigestMethod | //DigestMethod', ds_namespace).remove
              end

              it 'returns the default algorithm type' do
                expect(subject.send(
                         :digest_method_algorithm,
                         ref,
                         digest_method_fix_enabled
                       )).to eq OpenSSL::Digest::SHA1
              end
            end
          end
        end

        context 'digest_method_fix_enabled is false' do
          let(:digest_method_fix_enabled) { false }

          context 'document does not have ds namespace for Signature elements' do
            let(:xml_string) { fixture(:no_ds_namespace_request, false) }

            it 'returns the default algorithm type' do
              expect(subject.send(
                       :digest_method_algorithm,
                       ref,
                       digest_method_fix_enabled
                     )).to eq OpenSSL::Digest::SHA1
            end

            describe 'when the namespace hash is not defined' do
              it 'returns the default algorithm type' do
                expect(subject.send(
                         :digest_method_algorithm,
                         ref,
                         digest_method_fix_enabled
                       )).to eq OpenSSL::Digest::SHA1
              end
            end
          end

          context 'document does have ds namespace for Signature elements' do
            let(:xml_string) do
              SamlIdp::Request.from_deflated_request(
                signed_auth_request
              ).raw_xml
            end

            it 'returns the value in the DigestMethod node' do
              expect(subject.send(
                       :digest_method_algorithm,
                       ref,
                       digest_method_fix_enabled
                     )).to eq OpenSSL::Digest::SHA256
            end

            describe 'when the namespace hash is not defined' do
              it 'returns the value in the DigestMethod node' do
                # in this scenario, the undefined namespace hash is ignored
                expect(subject.send(
                         :digest_method_algorithm,
                         ref,
                         digest_method_fix_enabled
                       )).to eq OpenSSL::Digest::SHA256
              end
            end
          end
        end
      end

      describe 'Algorithms' do
        context 'SHA1' do
          let(:xml_string) { fixture(:adfs_response_sha1, false) }
          it 'validate using SHA1' do
            expect(subject.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
          end
        end

        context 'SHA256' do
          let(:xml_string) { fixture(:adfs_response_sha256, false) }
          it 'validate using SHA256' do
            expect(subject.validate('28:74:9B:E8:1F:E8:10:9C:A8:7C:A9:C3:E3:C5:01:6C:92:1C:B4:BA')).to be_truthy
          end
        end

        context 'SHA384' do
          let(:xml_string) { fixture(:adfs_response_sha384, false) }

          it 'validate using SHA384' do
            expect(subject.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
          end
        end

        context 'SHA512' do
          let(:xml_string) { fixture(:adfs_response_sha512, false) }

          it 'validate using SHA512' do
            expect(subject.validate('F1:3C:6B:80:90:5A:03:0E:6C:91:3E:5D:15:FA:DD:B0:16:45:48:72')).to be_truthy
          end
        end
      end
    end

    describe '#extract_inclusive_namespaces' do
      context 'explicit namespace resolution' do
        let(:xml_string) { fixture(:open_saml_response, false )}

        it 'supports explicit namespace resolution for exclusive canonicalization' do
          inclusive_namespaces = subject.send(:extract_inclusive_namespaces)

          expect(inclusive_namespaces).to eq(%w[xs])
        end
      end

      context 'implicit namespace resolution' do
        let(:xml_string) { fixture(:no_signature_ns, false )}

        it 'supports implicit namespace resolution for exclusive canonicalization' do
          inclusive_namespaces = subject.send(:extract_inclusive_namespaces)

          expect(inclusive_namespaces).to eq(%w[#default saml ds xs xsi])
        end
      end

      context 'inclusive namespace element is missing' do
        let(:xml_string) do
          xml = fixture(:no_signature_ns, false)
          xml.slice! %r{<InclusiveNamespaces xmlns="http://www.w3.org/2001/10/xml-exc-c14n#" PrefixList="#default saml ds xs xsi"/>}
          xml
        end

        it 'return an empty list when inclusive namespace element is missing' do
          inclusive_namespaces = subject.send(:extract_inclusive_namespaces)

          expect(inclusive_namespaces).to be_empty
        end
      end
    end
  end
end
