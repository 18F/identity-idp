require 'rails_helper'

RSpec.describe AttributeAsserter do
  include SamlAuthHelper

  let(:user) { create(:profile, :active, :verified).user }
  let(:facial_match_verified_user) do
    create(:profile, :active, :verified, idv_level: :in_person).user
  end
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
      semantic_authn_contexts_allowed?: false,
    )
  end

  let(:authn_context) do
    [
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
    ]
  end
  let(:options) { { authn_context: } }
  let(:raw_authn_request) do
    raw = saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
      }.merge(options),
    )

    CGI.unescape raw.split('SAMLRequest').last
  end

  let(:authn_request) do
    SamlIdp::Request.from_deflated_request(raw_authn_request)
  end

  let(:decrypted_pii) do
    Pii::Attributes.new_from_hash(
      first_name: 'Jåné',
      phone: '1 (888) 867-5309',
      zipcode: '  12345-1234',
      dob: '12/31/1970',
    )
  end

  let(:subject) do
    described_class.new(
      user:,
      name_id_format:,
      service_provider:,
      authn_request:,
      decrypted_pii:,
      user_session:,
    )
  end

  describe '#build' do
    context 'when an IAL2 request is made' do
      let(:authn_context) do
        [
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        ]
      end

      context 'when the user has been proofed without facial match' do
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
            expect(get_asserted_attribute(user, :first_name)).to eq 'Jåné'
          end

          it 'formats the phone number as e164' do
            expect(get_asserted_attribute(user, :phone)).to eq '+18888675309'
          end

          it 'gets UUID from Service Provider' do
            expect(get_asserted_attribute(user, :uuid)).to eq user.last_identity.uuid
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
            expect(get_asserted_attribute(user, :dob)).to eq '1970-12-31'
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
            expect(get_asserted_attribute(user, :zipcode)).to eq '12345'
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
            expect(get_asserted_attribute(user, :first_name)).to eq 'Jane'
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
            let(:authn_context) do
              [
                Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
              ]
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

      context 'when the user has been proofed with facial match' do
        let(:user) { create(:profile, :active, :verified, idv_level: :in_person).user }

        before do
          user.identities << identity
          subject.build
        end

        it 'asserts IAL2' do
          expected_ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    context 'verified user and proofing VTR request' do
      let(:authn_context) { 'C1.C2.P1' }

      before do
        user.identities << identity
        allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
          and_return(%w[email first_name last_name])
        subject.build
      end

      it 'includes the correct bundle attributes' do
        expect(user.asserted_attributes.keys).to eq(
          [:uuid, :email, :first_name, :last_name, :verified_at, :vot],
        )
        expect(get_asserted_attribute(user, :first_name)).to eq 'Jåné'
        expect(get_asserted_attribute(user, :vot)).to eq 'C1.C2.P1'
      end
    end

    context 'when an IAL1 request is made' do
      context 'when the user has been proofed without facial match comparison' do
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
            expect(get_asserted_attribute(user, :email)).to eq expected_email
          end

          it 'gets UUID from Service Provider' do
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

            it 'does not create a getter function for IAL1 attributes' do
              expected_email = EmailContext.new(user).last_sign_in_email_address.email
              expect(get_asserted_attribute(user, :email)).to eq expected_email
            end

            it 'gets UUID from Service Provider' do
              expect(get_asserted_attribute(user, :uuid)).to eq user.last_identity.uuid
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

          # rubocop:disable Layout/LineLength
          context 'authn request specifies bundle with first_name, last_name, email, ssn, phone' do
            let(:authn_context) do
              [
                Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
                Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
              ]
              # rubocop:enable Layout/LineLength
            end

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

        context 'request made with a VTR param' do
          let(:options) { { authn_context: 'C1.C2' } }

          before do
            user.identities << identity
            allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
              and_return(%w[email])
            subject.build
          end

          it 'includes the correct bundle attributes' do
            expect(user.asserted_attributes.keys).to eq(
              [:uuid, :email, :vot],
            )
            expect(get_asserted_attribute(user, :vot)).to eq 'C1.C2'
          end
        end
      end

      context 'when the user has been proofed with facial match comparison' do
        let(:user) { create(:profile, :active, :verified, idv_level: :in_person).user }

        before do
          user.identities << identity
          subject.build
        end

        it 'asserts IAL1' do
          expected_ial = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    context 'verified user and IAL1 AAL3 request' do
      context 'service provider configured for AAL3' do
        let(:service_provider_aal) { 3 }
        let(:authn_context) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'asserts AAL3' do
          expected_aal = Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :aal)).to eq expected_aal
        end
      end

      context 'service provider requests AAL3' do
        let(:authn_context) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          subject.build
        end

        it 'asserts AAL3' do
          expected_aal = Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :aal)).to eq expected_aal
        end
      end
    end

    context 'IALMAX' do
      context 'service provider requests IALMAX with IAL1 user' do
        let(:service_provider_ial) { 2 }
        let(:options) do
          {
            authn_context: [
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            ],
            authn_context_comparison: 'minimum',
          }
        end

        before do
          user.profiles.delete_all
          subject.build
        end

        it 'asserts IAL1' do
          expected_ial = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end

        it 'does not include proofed attributes' do
          expect(user.asserted_attributes[:first_name]).to eq(nil)
          expect(user.asserted_attributes[:phone]).to eq(nil)
        end
      end

      context 'IAL2 service provider requests IALMAX with IAL2 user' do
        let(:service_provider_ial) { 2 }
        let(:options) do
          {
            authn_context: [
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            ],
            authn_context_comparison: 'minimum',
          }
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          ServiceProvider.find_by(issuer: sp1_issuer).update!(ial: 2)
          subject.build
        end

        it 'asserts IAL2' do
          expected_ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end

        it 'includes proofed attributes' do
          expect(get_asserted_attribute(user, :first_name)).to eq('Jåné')
          expect(get_asserted_attribute(user, :phone)).to eq('+18888675309')
        end
      end
    end

    context 'non-IAL2 service provider requests IALMAX with IAL2 user' do
      let(:service_provider_ial) { 1 }
      let(:options) do
        {
          authn_context: [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ],
          authn_context_comparison: 'minimum',
        }
      end

      before do
        user.identities << identity
        allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
          and_return(%w[email phone first_name])
        ServiceProvider.find_by(issuer: sp1_issuer).update!(ial: 1)
        subject.build
      end

      it 'asserts IAL1' do
        expected_ial = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        expect(get_asserted_attribute(user, :ial)).to eq expected_ial
      end

      it 'does not include proofed attributes' do
        expect(user.asserted_attributes[:first_name]).to eq(nil)
        expect(user.asserted_attributes[:phone]).to eq(nil)
      end
    end

    context 'when facial match IAL preferred is requested' do
      let(:options) do
        {
          authn_context: [
            Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF,
          ],
        }
      end

      context 'when the user has been proofed with facial match' do
        let(:user) { facial_match_verified_user }

        before do
          user.identities << identity
          subject.build
        end

        it 'asserts IAL2 with facial match comparison' do
          expected_ial = Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end

      context 'when the user has been proofed without facial match' do
        before do
          user.identities << identity
          subject.build
        end

        it 'asserts IAL2 (without facial match comparison)' do
          expected_ial = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    context 'when facial match IAL required is requested' do
      let(:options) do
        {
          authn_context: [
            Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
          ],
        }
      end

      context 'when the user has been proofed with facial match comparison' do
        let(:user) { facial_match_verified_user }

        before do
          user.identities << identity
          subject.build
        end

        it 'asserts IAL2 with facial match comparison' do
          expected_ial = Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    shared_examples 'unverified user' do
      let(:user) { create(:user, :fully_registered) }

      context 'custom bundle does not include email, phone' do
        before do
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).and_return(
            %w[first_name last_name],
          )
          subject.build
        end

        it 'only includes UUID, aal, and ial' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid aal ial])
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
          all_emails_getter = user.asserted_attributes[:all_emails][:getter]
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
          expect(user.asserted_attributes.keys).to eq(%i[uuid email aal ial])
        end
      end
    end

    context 'unverified user and IAL2 request' do
      let(:user) { create(:user, :fully_registered) }
      let(:authn_context) do
        [
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        ]
      end

      it_behaves_like 'unverified user'
    end

    context 'unverified user and LOA1 request' do
      let(:user) { create(:user, :fully_registered) }

      let(:authn_context) do
        [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        ]
      end

      it_behaves_like 'unverified user'
    end

    context 'with a deleted email' do
      let(:subject) do
        described_class.new(
          user: user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      before do
        user.identities << identity
        allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
          and_return(%w[email phone first_name])
        create(:email_address, user:, email: 'email@example.com')

        ident = user.identities.last
        ident.email_address_id = user.email_addresses.first.id
        ident.save
        subject.build

        user.email_addresses.first.delete

        subject.build
      end

      it 'defers to user alternate email' do
        expect(get_asserted_attribute(user, :email)).
          to eq 'email@example.com'
      end
    end

    context 'with a nil email id' do
      let(:subject) do
        described_class.new(
          user: user,
          name_id_format: name_id_format,
          service_provider: service_provider,
          authn_request: authn_request,
          decrypted_pii: decrypted_pii,
          user_session: user_session,
        )
      end

      before do
        user.identities << identity
        allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
          and_return(%w[email phone first_name])

        ident = user.identities.last
        ident.email_address_id = nil
        ident.save
        subject.build
      end

      it 'defers to user alternate email' do
        expect(get_asserted_attribute(user, :email)).
          to eq user.email_addresses.last.email
      end
    end

    context 'select email to send to partner feature is disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :feature_select_email_to_share_enabled,
        ).and_return(false)
      end

      context 'with a deleted email' do
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])
          create(:email_address, user:, email: 'email@example.com')

          ident = user.identities.last
          ident.email_address_id = user.email_addresses.first.id
          ident.save
          subject.build

          user.email_addresses.first.delete

          subject.build
        end

        it 'defers to user alternate email' do
          expect(get_asserted_attribute(user, :email)).
            to eq 'email@example.com'
        end
      end

      context 'with a nil email id' do
        let(:subject) do
          described_class.new(
            user: user,
            name_id_format: name_id_format,
            service_provider: service_provider,
            authn_request: authn_request,
            decrypted_pii: decrypted_pii,
            user_session: user_session,
          )
        end

        before do
          user.identities << identity
          allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
            and_return(%w[email phone first_name])

          ident = user.identities.last
          ident.email_address_id = nil
          ident.save
          subject.build
        end

        it 'defers to user alternate email' do
          expect(get_asserted_attribute(user, :email)).
            to eq user.email_addresses.last.email
        end
      end
    end
  end

  describe 'aal attributes handling' do
    before do
      user.identities << identity
      allow(service_provider.metadata).to receive(:[]).with(:attribute_bundle).
        and_return(%w[email])
      subject.build
    end

    describe 'when no aal requested' do
      context 'default_aal is nil' do
        let(:authn_context) { [] }

        it 'asserts default aal' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 1' do
        let(:service_provider_aal) { 1 }
        let(:authn_context) { [] }

        it 'asserts aal1' do
          # we do not enforce aal1, we enforce default aal, so this should be updated
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 2' do
        let(:service_provider_aal) { 2 }
        let(:authn_context) { [] }

        it 'asserts aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 3' do
        let(:service_provider_aal) { 3 }
        let(:authn_context) { [] }

        it 'asserts aa33' do
          # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
          # so should be updated
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end
    end

    describe 'when aal is passed in via authn_context' do
      context 'aal1 is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF }

        # We do not support AAL1. when passed in, we enforce our default AAL value.
        # However, we are returning the AAL1 value, which is misleading.
        it 'asserts default aal' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal2 is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }

        it 'asserts plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal2 with phishing-resistant mfa is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF }

        # we should assert the more specific aal2 value
        it 'asserts plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal2 with hspd12 mfa requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF }

        # we should assert the more specific aal2 value
        it 'asserts plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      # we need to deprecate AAL3 values, as we are not enforcing AAL3.
      context 'aal3 requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }

        # when aal3 is requested, we are enforcing aal2 with phishing-resistant mfa.
        # we should update to assert that
        it 'asserts plain aal3' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal3 with hspd12 mfa requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF }

        # when aal3 is requested, we are enforcing aal2 with HSPD12 mfa.
        # we should update to assert that
        it 'asserts plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      describe 'when multiple aal values are requested via authn_context' do
        # currently, if values are passed in the request, the saml_idp gem only
        # returns the first option.
        context 'default is first' do
          let(:authn_context) do
            [
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
            ]
          end

          it 'asserts the default value' do
            expect(get_asserted_attribute(user, :aal)).to eq(
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            )
          end
        end

        context 'aal1 is first' do
          let(:authn_context) do
            [
              Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            ]
          end

          it 'asserts the aal1 value' do
            expect(get_asserted_attribute(user, :aal)).to eq(
              Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
            )
          end
        end
      end
    end

    describe 'ial is passed in via authn_context' do
      context 'auth-only is requested' do
        let(:authn_context) { [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF] }

        describe 'no aal is requested via authn_context' do
          context 'default_aal is nil' do
            it 'asserts default aal' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 1' do
            let(:service_provider_aal) { 1 }

            it 'asserts aal1' do
              # we do not enforce aal1, we enforce default aal, so this should be updated
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 2' do
            let(:service_provider_aal) { 2 }

            it 'asserts aal1' do
              # we do not enforce aal1, we enforce default aal, so this should be updated
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 3' do
            let(:service_provider_aal) { 3 }

            it 'asserts aal1' do
              # we do not enforce aal1, we enforce default aal, so this should be updated
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end
      end

      context 'identity-proofing is requested' do
        let(:authn_context) { [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF] }

        describe 'no aal is requested via authn_context' do
          context 'default_aal is nil' do
            it 'asserts default aal' do
              # this should be upgraded to AAL2, as we enforce that on an identity-proofing request
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 1' do
            let(:service_provider_aal) { 1 }

            it 'asserts aal1' do
              # this should be upgraded to AAL2, as we enforce that on an identity-proofing request
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 2' do
            let(:service_provider_aal) { 2 }

            it 'asserts base aal2' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 3' do
            let(:service_provider_aal) { 3 }

            it 'asserts aal3' do
              # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end

        describe 'multiple aal values are requested' do
          context 'default is first' do
            let(:authn_context) do
              [
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              ]
            end

            # identity proofing enforces aal2, so that is what should be asserted
            it 'asserts the default value' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end
      end

      context 'ialmax is requested' do
        let(:options) do
          {
            authn_context: [
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            ],
            authn_context_comparison: 'minimum',
          }
        end

        context 'a non-verified user' do
          # remove any profiles
          before do
            user.profiles.delete_all
            subject.build
          end

          describe 'no aal is requested via authn_context' do
            context 'default_aal is nil' do
              it 'asserts default aal' do
                # this is fine, as we have enforced auth-only
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 1' do
              let(:service_provider_aal) { 1 }

              it 'asserts aal1' do
                # this is fine, as we have enforced auth-only
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 2' do
              let(:service_provider_aal) { 2 }

              it 'asserts base aal2' do
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 3' do
              let(:service_provider_aal) { 3 }

              it 'asserts aal3' do
                # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end
          end
        end

        context 'a verified user' do
          describe 'no aal is requested via authn_context' do
            context 'default_aal is nil' do
              it 'asserts default aal' do
                # this should be upgraded to AAL2, as we enforce that
                # on an identity-proofing request
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 1' do
              let(:service_provider_aal) { 1 }

              it 'asserts aal1' do
                # this should be upgraded to AAL2, as we enforce that
                # on an identity-proofing request
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 2' do
              let(:service_provider_aal) { 2 }

              it 'asserts base aal2' do
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 3' do
              let(:service_provider_aal) { 3 }

              it 'asserts aal3' do
                # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end
          end
        end
      end
    end
  end

  def get_asserted_attribute(user, attribute)
    user.asserted_attributes[attribute][:getter].call(user)
  end
end
