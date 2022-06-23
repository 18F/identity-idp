require 'rails_helper'

describe AttributeAsserter do
  include SamlAuthHelper

  let(:ial1_user) { create(:user, :signed_up) }
  let(:user) { create(:profile, :active, :verified).user }
  let(:user_session) { {} }
  let(:identity) do
    build(
      :service_provider_identity,
      service_provider: service_provider.issuer,
      session_uuid: SecureRandom.uuid,
    )
  end
  let(:name_id_format) { Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT }
  let(:service_provider_ial) { 1 }
  let(:service_provider_aal) { nil }
  let(:service_provider) do
    instance_double(
      ServiceProvider,
      issuer: 'http://localhost:3000',
      ial: service_provider_ial,
      default_aal: service_provider_aal,
      metadata: {},
    )
  end
  let(:raw_sp1_authn_request) do
    sp1_authnrequest = saml_authn_request_url(overrides: { issuer: sp1_issuer })
    CGI.unescape sp1_authnrequest.split('SAMLRequest').last
  end
  let(:raw_aal3_sp1_authn_request) do
    ial1_aal3_authnrequest = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
        ],
      },
    )
    CGI.unescape ial1_aal3_authnrequest.split('SAMLRequest').last
  end
  let(:raw_ial1_authn_request) do
    ial1_authn_request_url = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      },
    )
    CGI.unescape ial1_authn_request_url.split('SAMLRequest').last
  end
  let(:raw_ial2_authn_request) do
    ial2_authnrequest = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      },
    )
    CGI.unescape ial2_authnrequest.split('SAMLRequest').last
  end
  let(:raw_ial1_aal3_authn_request) do
    ial1_aal3_authnrequest = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
        ],
      },
    )
    CGI.unescape ial1_aal3_authnrequest.split('SAMLRequest').last
  end
  let(:raw_ialmax_authn_request) do
    ialmax_authnrequest = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        ],
        authn_context_comparison: 'minimum',
      },
    )
    CGI.unescape ialmax_authnrequest.split('SAMLRequest').last
  end
  let(:sp1_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_sp1_authn_request)
  end
  let(:aal3_sp1_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_aal3_sp1_authn_request)
  end
  let(:ial1_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_ial1_authn_request)
  end
  let(:ial2_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_ial2_authn_request)
  end
  let(:ial1_aal3_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_ial1_aal3_authn_request)
  end
  let(:ialmax_authn_request) do
    SamlIdp::Request.from_deflated_request(raw_ialmax_authn_request)
  end
  let(:decrypted_pii) do
    Pii::Attributes.new_from_hash(
      first_name: 'Jåné',
      phone: '1 (888) 867-5309',
      zipcode: '  12345-1234',
      dob: '12/31/1970',
    )
  end

  describe '#build' do
    context 'verified user and IAL2 request' do
      let(:subject) do
        described_class.new(
          user: user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: ial2_authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      context 'custom bundle includes email, phone, and first_name' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'includes all requested attributes + uuid' do
          expect(user.asserted_attributes.keys).
            to eq(%i[uuid email phone first_name verified_at aal ial])
        end

        it 'creates getter function' do
          expect(user.asserted_attributes[:first_name][:getter].call(user)).to eq 'Jåné'
        end

        it 'formats the phone number as e164' do
          expect(user.asserted_attributes[:phone][:getter].call(user)).to eq '+18888675309'
        end

        it 'gets UUID (MBUN) from Service Provider' do
          uuid_getter = user.asserted_attributes[:uuid][:getter]
          expect(uuid_getter.call(user)).to eq user.last_identity.uuid
        end
      end

      context 'custom bundle includes dob' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[dob])
          subject.build
        end

        it 'formats the dob in an international format' do
          expect(user.asserted_attributes[:dob][:getter].call(user)).to eq '1970-12-31'
        end
      end

      context 'custom bundle includes zipcode' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[zipcode])
          subject.build
        end

        it 'formats zipcode as 5 digits' do
          expect(user.asserted_attributes[:zipcode][:getter].call(user)).to eq '12345'
        end
      end

      context 'bundle includes :ascii' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name ascii])
          subject.build
        end

        it 'skips ascii as an attribute' do
          expect(user.asserted_attributes.keys).
            to eq(%i[uuid email phone first_name verified_at aal ial])
        end

        it 'transliterates attributes to ASCII' do
          expect(user.asserted_attributes[:first_name][:getter].call(user)).to eq 'Jane'
        end
      end

      context 'Service Provider does not specify bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(nil)
          subject.build
        end

        context 'authn request does not specify bundle' do
          it 'only returns uuid, verified_at, aal, and ial' do
            expect(user.asserted_attributes.keys).to eq %i[uuid verified_at aal ial]
          end
        end

        context 'authn request specifies bundle' do
          # rubocop:disable Layout/LineLength
          let(:raw_ial2_authn_request) do
            request_url = saml_authn_request_url(
              overrides: {
                issuer: sp1_issuer,
                authn_context: [
                  Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
              },
            )
            CGI.unescape(
              request_url.split('SAMLRequest').last,
            )
          end
          # rubocop:enable Layout/LineLength

          it 'uses authn request bundle' do
            expect(user.asserted_attributes.keys).
              to eq(%i[uuid email first_name last_name ssn phone verified_at aal ial])
          end
        end
      end

      context 'Service Provider specifies empty bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return([])
          subject.build
        end

        it 'only includes uuid, verified_at, aal, and ial' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid verified_at aal ial])
        end
      end

      context 'custom bundle has invalid attribute name' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[email foo],
          )
          subject.build
        end

        it 'silently skips invalid attribute name' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid email verified_at aal ial])
        end
      end

      context 'x509 attributes included in the SP attribute bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email x509_subject x509_issuer x509_presented])
          subject.build
        end

        context 'user did not present piv/cac' do
          let(:user_session) do
            {
              decrypted_x509: nil,
            }
          end

          it 'does not include x509_subject, x509_issuer, and x509_presented' do
            expect(user.asserted_attributes.keys).to eq %i[uuid email verified_at aal ial]
          end
        end

        context 'user presented piv/cac' do
          let(:user_session) do
            {
              decrypted_x509: {
                subject: 'x509 subject',
                presented: true,
              }.to_json,
            }
          end

          it 'includes x509_subject x509_issuer x509_presented' do
            expected = %i[uuid email verified_at aal ial x509_subject x509_issuer x509_presented]
            expect(user.asserted_attributes.keys).to eq expected
          end
        end
      end
    end

    context 'verified user and IAL1 request' do
      let(:subject) do
        described_class.new(
          user: user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: sp1_authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      context 'custom bundle includes email, phone, and first_name' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'only includes uuid, email, aal, and ial (no verified_at)' do
          expect(user.asserted_attributes.keys).to eq %i[uuid email aal ial]
        end

        it 'does not create a getter function for IAL1 attributes' do
          expected_email = EmailContext.new(user).last_sign_in_email_address.email
          expect(user.asserted_attributes[:email][:getter].call(user)).to eq expected_email
        end

        it 'gets UUID (MBUN) from Service Provider' do
          uuid_getter = user.asserted_attributes[:uuid][:getter]
          expect(uuid_getter.call(user)).to eq user.last_identity.uuid
        end
      end

      context 'custom bundle includes verified_at' do
        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email verified_at])
          subject.build
        end

        context 'the service provider is ial1' do
          let(:service_provider_ial) { 1 }

          it 'only includes uuid, email, aal, and ial (no verified_at)' do
            expect(user.asserted_attributes.keys).to eq %i[uuid email aal ial]
          end
        end

        context 'the service provider is ial2' do
          let(:service_provider_ial) { 2 }

          it 'includes verified_at' do
            expect(user.asserted_attributes.keys).to eq %i[uuid email verified_at aal ial]
          end
        end
      end

      context 'Service Provider does not specify bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(nil)
          subject.build
        end

        context 'authn request does not specify bundle' do
          it 'only includes uuid, aal, and ial' do
            expect(user.asserted_attributes.keys).to eq %i[uuid aal ial]
          end
        end

        context 'authn request specifies bundle with first_name, last_name, email, ssn, phone' do
          # rubocop:disable Layout/LineLength
          let(:raw_sp1_authn_request) do
            request_url = saml_authn_request_url(
              overrides: {
                issuer: sp1_issuer,
                authn_context: [
                  Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
                  Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ],
              },
            )
            CGI.unescape(
              request_url.split('SAMLRequest').last,
            )
          end
          # rubocop:enable Layout/LineLength

          it 'only includes uuid, email, aal, and ial' do
            expect(user.asserted_attributes.keys).to eq(%i[uuid email aal ial])
          end
        end
      end

      context 'Service Provider specifies empty bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return([])
          subject.build
        end

        it 'only includes UUID, aal, and ial' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid aal ial])
        end
      end

      context 'custom bundle has invalid attribute name' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[email foo],
          )
          subject.build
        end

        it 'silently skips invalid attribute name' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid email aal ial])
        end
      end

      context 'x509 attributes included in the SP attribute bundle' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email x509_subject x509_issuer x509_presented])
          subject.build
        end

        context 'user did not present piv/cac' do
          let(:user_session) do
            {
              decrypted_x509: nil,
            }
          end

          it 'does not include x509_subject x509_issuer and x509_presented' do
            expect(user.asserted_attributes.keys).to eq %i[uuid email aal ial]
          end
        end

        context 'user presented piv/cac' do
          let(:user_session) do
            {
              decrypted_x509: {
                subject: 'x509 subject',
                presented: true,
              }.to_json,
            }
          end

          it 'includes x509_subject x509_issuer and x509_presented' do
            expected = %i[uuid email aal ial x509_subject x509_issuer x509_presented]
            expect(user.asserted_attributes.keys).to eq expected
          end
        end
      end
    end

    context 'verified user and IAL1 AAL3 request' do
      context 'service provider configured for AAL3' do
        let(:service_provider_aal) { 3 }
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: aal3_sp1_authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'includes aal' do
          expect(user.asserted_attributes.keys).to include(:aal)
        end

        it 'creates a getter function for aal attribute' do
          expected_aal = Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          expect(user.asserted_attributes[:aal][:getter].call(user)).to eq expected_aal
        end
      end

      context 'service provider requests AAL3' do
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: ial1_aal3_authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'includes aal' do
          expect(user.asserted_attributes.keys).to include(:aal)
        end

        it 'creates a getter function for aal attribute' do
          expected_aal = Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          expect(user.asserted_attributes[:aal][:getter].call(user)).to eq expected_aal
        end
      end
    end

    context 'IALMAX' do
      context 'service provider requests IALMAX with IAL1 user' do
        let(:service_provider_ial) { 2 }
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: ialmax_authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.profiles.delete_all
          subject.build
        end

        it 'includes ial' do
          expect(user.asserted_attributes.keys).to include(:ial)
        end

        it 'creates a getter function for ial attribute' do
          expected_ial = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
          expect(user.asserted_attributes[:ial][:getter].call(user)).to eq expected_ial
        end
      end

      context 'service provider requests IALMAX with IAL2 user' do
        let(:service_provider_ial) { 2 }
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: ialmax_authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'includes ial' do
          expect(user.asserted_attributes.keys).to include(:ial)
        end

        it 'creates a getter function for ial attribute' do
          expected_ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          expect(user.asserted_attributes[:ial][:getter].call(user)).to eq expected_ial
        end
      end
    end

    shared_examples 'unverified user' do
      context 'custom bundle does not include email, phone' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[first_name last_name],
          )
          subject.build
        end

        it 'only includes UUID, aal, and ial' do
          expect(ial1_user.asserted_attributes.keys).to eq(%i[uuid aal ial])
        end
      end

      context 'custom bundle includes all_emails' do
        before do
          create(:email_address, user: user)
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[all_emails],
          )
          subject.build
        end

        it 'includes all the user email addresses' do
          all_emails_getter = ial1_user.asserted_attributes[:all_emails][:getter]
          emails = all_emails_getter.call(user)
          expect(emails.length).to eq(2)
          expect(emails).to match_array(user.confirmed_email_addresses.map(&:email))
        end
      end

      context 'custom bundle includes email, phone' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[first_name last_name email phone],
          )
          subject.build
        end

        it 'only includes UUID, email, aal, and ial' do
          expect(ial1_user.asserted_attributes.keys).to eq(%i[uuid email aal ial])
        end
      end
    end

    context 'unverified user and IAL2 request' do
      let(:subject) do
        described_class.new(
          user: ial1_user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: ial2_authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      it_behaves_like 'unverified user'
    end

    context 'unverified user and LOA1 request' do
      let(:subject) do
        described_class.new(
          user: ial1_user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: ial1_authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      it_behaves_like 'unverified user'
    end
  end
end
