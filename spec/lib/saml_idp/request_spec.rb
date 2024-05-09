require 'spec_helper'
module SamlIdp
  describe Request do
    let(:aal) { 'http://idmanagement.gov/ns/assurance/aal/3' }
    let(:default_aal) { 'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo' }
    let(:ial) { 'http://idmanagement.gov/ns/assurance/ial/2' }
    let(:vtr) { 'C1.C2.P1.Pb' }
    let(:password) { 'urn:oasis:names:tc:SAML:2.0:ac:classes:Password' }
    let(:authn_context_classref) { build_authn_context_classref(password) }
    let(:issuer) { 'localhost:3000' }
    let(:raw_authn_request) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>#{issuer}</saml:Issuer><samlp:NameIDPolicy AllowCreate='true' Format='urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'/><samlp:RequestedAuthnContext Comparison='exact'>#{authn_context_classref}</samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    let(:raw_authn_unspecified_name_id_format) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>#{issuer}</saml:Issuer><samlp:RequestedAuthnContext Comparison='exact'><saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef></samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    let(:raw_authn_forceauthn_present) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' ForceAuthn='true' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>#{issuer}</saml:Issuer><samlp:RequestedAuthnContext Comparison='exact'><saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef></samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    let(:raw_authn_forceauthn_false) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' ForceAuthn='false' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>#{issuer}</saml:Issuer><samlp:RequestedAuthnContext Comparison='exact'><saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef></samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    let(:raw_authn_enveloped_signature) { "<samlp:AuthnRequest AssertionConsumerServiceURL='http://localhost:3000/saml/consume' Destination='http://localhost:1337/saml/auth' ID='_af43d1a0-e111-0130-661a-3c0754403fdb' IssueInstant='2013-08-06T22:01:35Z' Version='2.0' ForceAuthn='false' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'><saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>localhost:3000</saml:Issuer><ds:Signature xmlns:ds='http://www.w3.org/2000/09/xmldsig#'></ds:Signature><samlp:RequestedAuthnContext Comparison='exact'><saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>urn:oasis:names:tc:SAML:2.0:ac:classes:Password</saml:AuthnContextClassRef></samlp:RequestedAuthnContext></samlp:AuthnRequest>" }

    let(:raw_logout_request) { "<LogoutRequest ID='_some_response_id' Version='2.0' IssueInstant='2010-06-01T13:00:00Z' Destination='http://localhost:3000/saml/logout' xmlns='urn:oasis:names:tc:SAML:2.0:protocol'><Issuer xmlns='urn:oasis:names:tc:SAML:2.0:assertion'>http://example.com</Issuer><NameID xmlns='urn:oasis:names:tc:SAML:2.0:assertion' Format='urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'>some_name_id</NameID><SessionIndex>abc123index</SessionIndex></LogoutRequest>" }

    describe 'deflated request' do
      let(:deflated_request) { Base64.encode64(Zlib::Deflate.deflate(raw_authn_request, 9)[2..-5]) }

      subject { described_class.from_deflated_request deflated_request }

      it 'inflates' do
        expect(subject.request_id).to eq('_af43d1a0-e111-0130-661a-3c0754403fdb')
      end

      it 'handles invalid SAML' do
        req = described_class.from_deflated_request 'bang!'
        expect(req.valid?).to eq(false)
      end
    end

    describe 'authn request' do
      subject { described_class.new raw_authn_request }

      it 'has a valid request_id' do
        expect(subject.request_id).to eq('_af43d1a0-e111-0130-661a-3c0754403fdb')
      end

      it 'has a valid acs_url' do
        expect(subject.acs_url).to eq('http://localhost:3000/saml/consume')
      end

      it 'has a valid service_provider' do
        expect(subject.service_provider).to be_a ServiceProvider
      end

      it 'has a valid service_provider' do
        expect(subject.service_provider).to be_truthy
      end

      it 'has a valid issuer' do
        expect(subject.issuer).to eq('localhost:3000')
      end

      it 'has a valid valid_signature' do
        expect(subject.valid_signature?).to be_truthy
      end

      it "correctly indicates that it isn't signed" do
        expect(subject.signed?).to be_falsey
      end

      context 'with signature in params' do
        subject do
          described_class.new(raw_authn_request, get_params: { Signature: 'abc' })
        end

        it 'correctly indicates that it is signed (even invalidly)' do
          expect(subject.signed?).to be_truthy
        end
      end

      context 'with an enveloped signature' do
        subject { described_class.new raw_authn_enveloped_signature }

        it 'correctly indicates that it is signed (even invalidly)' do
          expect(subject.signed?).to be_truthy
        end
      end

      it 'should return acs_url for response_url' do
        expect(subject.response_url).to eq(subject.acs_url)
      end

      it 'is a authn request' do
        expect(subject.authn_request?).to eq(true)
      end

      it 'fetches internal request' do
        expect(subject.request['ID']).to eq(subject.request_id)
      end

      it 'has a valid name id format' do
        expect(subject.name_id_format).to eq('urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress')
      end

      it 'has a valid requested authn context comparison' do
        expect(subject.requested_authn_context_comparison).to eq('exact')
      end

      it 'has a valid authn context' do
        expect(subject.requested_authn_context).to eq('urn:oasis:names:tc:SAML:2.0:ac:classes:Password')
      end

      context 'empty issuer' do
        let(:issuer) { nil }

        it 'does not permit empty issuer' do
          expect(subject.issuer).not_to eq('')
          expect(subject.issuer).to eq(nil)
        end
      end

      it 'defaults to force_authn = false' do
        expect(subject.force_authn?).to be_falsey
      end

      it 'properly parses ForceAuthn="true" if passed' do
        authn_request = described_class.new raw_authn_forceauthn_present

        expect(authn_request.force_authn?).to be_truthy
      end

      it 'properly parses ForceAuthn="false" if passed' do
        authn_request = described_class.new raw_authn_forceauthn_false

        expect(authn_request.force_authn?).to be_falsey
      end

      describe 'unspecified name id format' do
        subject { described_class.new raw_authn_unspecified_name_id_format }

        it 'returns nil for name id format' do
          expect(subject.name_id_format).to eq(nil)
        end
      end
    end

    describe 'logout request' do
      subject { described_class.new raw_logout_request }

      it 'has a valid request_id' do
        expect(subject.request_id).to eq('_some_response_id')
      end

      it 'should be flagged as a logout_request' do
        expect(subject.logout_request?).to eq(true)
      end

      it 'should have a valid name_id' do
        expect(subject.name_id).to eq('some_name_id')
      end

      it 'should have a session index' do
        expect(subject.session_index).to eq('abc123index')
      end

      it 'should have a valid issuer' do
        expect(subject.issuer).to eq('http://example.com')
      end

      it 'fetches internal request' do
        expect(subject.request['ID']).to eq(subject.request_id)
      end

      it 'should return logout_url for response_url' do
        expect(subject.response_url).to eq(subject.logout_url)
      end
    end

    describe '#requested_aal_authn_context' do
      subject { described_class.new raw_authn_request }

      context 'no aal context requested' do
        let(:authn_context_classref) { '' }

        it 'should return nil' do
          expect(subject.requested_aal_authn_context).to be_nil
        end
      end

      context 'context requested is default aal' do
        let(:authn_context_classref) { build_authn_context_classref(default_aal) }

        it 'should return the aal uri' do
          expect(subject.requested_aal_authn_context).to eq(default_aal)
        end
      end

      context 'only context requested is aal' do
        let(:authn_context_classref) { build_authn_context_classref(aal) }

        it 'should return the aal uri' do
          expect(subject.requested_aal_authn_context).to eq(aal)
        end
      end

      context 'multiple contexts requested including aal' do
        let(:authn_context_classref) { build_authn_context_classref([ial, aal]) }

        it 'should return the aal uri' do
          expect(subject.requested_aal_authn_context).to eq(aal)
        end
      end
    end

    describe '#requested_ial_authn_context' do
      subject { described_class.new raw_authn_request }

      context 'no ial context requested' do
        let(:authn_context_classref) { '' }

        it 'should return nil' do
          expect(subject.requested_ial_authn_context).to be_nil
        end
      end

      context 'only context requested is ial' do
        let(:authn_context_classref) { build_authn_context_classref(ial) }

        it 'should return the ial uri' do
          expect(subject.requested_ial_authn_context).to eq(ial)
        end
      end

      context 'multiple contexts requested including ial' do
        let(:authn_context_classref) { build_authn_context_classref([aal, ial]) }

        it 'should return the ial uri' do
          expect(subject.requested_ial_authn_context).to eq(ial)
        end
      end
    end

    describe '#requested_vtr_authn_context' do
      subject { described_class.new raw_authn_request }

      context 'no vtr context requested' do
        let(:authn_context_classref) { '' }

        it 'should return nil' do
          expect(subject.requested_vtr_authn_context).to be_nil
        end
      end

      context 'only vtr is requested' do
        let(:authn_context_classref) { build_authn_context_classref(vtr) }

        it 'should return the vrt' do
          expect(subject.requested_vtr_authn_context).to eq(vtr)
        end
      end

      context 'multiple contexts including vtr' do
        let(:authn_context_classref) { build_authn_context_classref([vtr, ial]) }

        it 'should return the vrt' do
          expect(subject.requested_vtr_authn_context).to eq(vtr)
        end
      end

      context 'context that contains a VTR substring but is not a VTR' do
        let(:authn_context_classref) do
          fake_vtr = 'Not a VTR but does contain LetT3.Rs and Nu.Mb.Ers'
          build_authn_context_classref(fake_vtr)
        end

        it 'does not match on the context' do
          expect(subject.requested_vtr_authn_context).to be_nil
        end
      end

      context 'with the default MFA context' do
        let(:aal) { 'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo' }
        let(:authn_context_classref) { build_authn_context_classref(aal) }

        it 'does not match on the context' do
          expect(subject.requested_vtr_authn_context).to be_nil
        end
      end
    end

    describe '#valid?' do
      let(:request_saml) { raw_authn_request }
      subject { described_class.new request_saml }

      context 'a valid request' do
        it 'returns true' do
          expect(subject.valid?).to be true
        end

        it 'has no errors' do
          expect(subject.errors.blank?).to be true
        end
      end

      context 'an invalid request' do
        describe 'a request with no issuer' do
          let(:issuer) { nil }

          it 'is not valid' do
            expect(subject.valid?).to eq(false)
          end

          it 'adds an error to the request object' do
            subject.valid?
            expect(subject.errors.first).to eq :issuer_missing_or_invald
          end
        end

        describe 'no authn_request OR logout_request tag' do
          let(:request_saml) do
            "<saml:Issuer xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>localhost:3000</saml:Issuer><samlp:NameIDPolicy AllowCreate='true' Format='urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress' xmlns:samlp='urn:oasis:names:tc:SAML:2.0:protocol'/><samlp:RequestedAuthnContext Comparison='exact'>#{authn_context_classref}</samlp:RequestedAuthnContext>"
          end

          it 'is not valid' do
            expect(subject.valid?).to eq false
          end

          it 'adds an error to request object' do
            subject.valid?
            expect(subject.errors.first).to eq :no_auth_or_logout_request
          end
        end

        describe 'both an authn_request AND logout_request tag' do
          let(:logout_saml) { "<LogoutRequest ID='_some_response_id' Version='2.0' IssueInstant='2010-06-01T13:00:00Z' Destination='http://localhost:3000/saml/logout' xmlns='urn:oasis:names:tc:SAML:2.0:protocol'>" }

          let(:request_saml) do
            logout_saml + raw_authn_request + '</LogoutRequest>'
          end

          it 'is not valid' do
            expect(subject.valid?).to eq false
          end

          it 'adds an error to request object' do
            subject.valid?
            expect(subject.errors.first).to eq :both_auth_and_logout_request
          end
        end

        describe 'there is no response url' do
          describe 'authn_request' do
            let(:request_saml) do
              raw_authn_request.gsub("AssertionConsumerServiceURL='http://localhost:3000/saml/consume'", '')
            end

            it 'is not valid' do
              expect(subject.valid?).to eq false
            end

            it 'adds an error to request object' do
              subject.valid?
              expect(subject.errors.first).to eq :no_response_url
            end
          end

          describe 'logout_request' do
            let(:request_saml) { raw_logout_request }
            before do
              subject.service_provider.assertion_consumer_logout_service_url = nil
            end

            it 'is not valid' do
              expect(subject.valid?).to eq false
            end

            it 'adds an error to request object' do
              subject.valid?
              expect(subject.errors.first).to eq :no_response_url
            end
          end
        end

        describe 'invalid signature' do
          subject do
            # the easiest way to "force" a signature check is to make it a logout request
            described_class.new(raw_logout_request, get_params: { Signature: 'abc' })
          end

          it 'is not valid' do
            expect(subject.valid?).to eq false
          end

          it 'adds an error to request object' do
            subject.valid?
            expect(subject.errors.include?(:invalid_signature)).to be true
          end
        end
      end
    end

    describe '#matching_cert' do
      let(:saml_request) { make_saml_request }

      subject do
        described_class.from_deflated_request saml_request
      end

      describe 'document is not signed' do
        it 'returns nil' do
          expect(subject.matching_cert).to be nil
        end
      end

      describe 'document is signed' do
        let(:saml_request) { signed_auth_request }
        let(:service_provider)  { subject.service_provider }
        let(:cert) { saml_settings.get_sp_cert }

        describe 'the service provider has no registered certs' do
          before { subject.service_provider.certs = [] }

          it 'returns nil' do
            expect(subject.matching_cert).to be nil
          end
        end

        describe 'the service provider has one registered cert' do
          before { subject.service_provider.certs = [cert] }

          describe 'the cert matches the assertion cert' do
            it 'returns the cert' do
              expect(subject.matching_cert).to eq cert
            end
          end

          describe 'the cert does not match the assertion cert' do
            let(:cert) { OpenSSL::X509::Certificate.new(cloudhsm_idp_x509_cert) }
            it 'returns nil' do
              expect(subject.matching_cert).to be nil
            end
          end

        end

        describe 'multiple certs' do
          let(:not_matching_cert) { OpenSSL::X509::Certificate.new(cloudhsm_idp_x509_cert) }

          before { subject.service_provider.certs = [not_matching_cert, invalid_cert, cert] }

          it 'returns the matching cert' do
            expect(subject.matching_cert).to eq cert
          end
        end
      end
    end

    def build_authn_context_classref(contexts)
      [contexts].flatten.map do |c|
        "<saml:AuthnContextClassRef xmlns:saml='urn:oasis:names:tc:SAML:2.0:assertion'>#{c}</saml:AuthnContextClassRef>"
      end.join
    end
  end
end
