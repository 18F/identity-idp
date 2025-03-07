require 'rails_helper'

RSpec.describe AttributeAsserter do
  include SamlAuthHelper

  let(:user) { create(:profile, :active, :verified).user }
  let(:facial_match_verified_user) do
    create(:profile, :active, :verified, idv_level: :in_person).user
  end
  let(:user_session) { { web_locale: 'en' } }
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
  let(:attribute_bundle) { nil }
  let(:service_provider) do
    create(
      :service_provider,
      ial: service_provider_ial,
      default_aal: service_provider_aal,
      attribute_bundle:,
    )
  end
  let(:fake_analytics) { FakeAnalytics.new(user: user) }

  let(:authn_context) do
    [
      Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
    ]
  end
  let(:options) { { authn_context: } }
  let(:raw_authn_request) do
    raw = saml_authn_request_url(
      overrides: {
        issuer: service_provider.issuer,
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

  before do
    allow(Analytics).to receive(:new).and_return(fake_analytics)
    stub_analytics
  end

  describe '#build' do
    context 'when an IAL2 request is made' do
      before do
        user.identities << identity
        subject.build
      end

      [
        Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ]
        .each do |ial_value|
        let(:authn_context) do
          [
            ial_value,
          ]
        end

        context 'when the user has been proofed without facial match' do
          context 'custom bundle includes email, phone, and first_name' do
            let(:attribute_bundle) { %w[email phone first_name] }

            it 'includes all requested attributes + uuid' do
              expect(user.asserted_attributes.keys)
                .to eq(%i[uuid email phone first_name verified_at aal ial])
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

            context 'when authn_context includes an unknown value' do
              let(:authn_context) do
                [
                  ial_value,
                  'unknown/authn/context',
                ]
              end

              it 'includes all requested attributes + uuid' do
                expect(user.asserted_attributes.keys)
                  .to eq(%i[uuid email phone first_name verified_at aal ial])
              end
            end
          end

          context 'custom bundle includes dob' do
            let(:attribute_bundle) { %w[dob] }

            it 'formats the dob in an international format' do
              expect(get_asserted_attribute(user, :dob)).to eq '1970-12-31'
            end
          end

          context 'custom bundle includes zipcode' do
            let(:attribute_bundle) { %w[zipcode] }

            it 'formats zipcode as 5 digits' do
              expect(get_asserted_attribute(user, :zipcode)).to eq '12345'
            end
          end

          context 'bundle includes :ascii' do
            let(:attribute_bundle) { %w[email phone first_name ascii] }

            it 'skips ascii as an attribute' do
              expect(user.asserted_attributes.keys)
                .to eq(%i[uuid email phone first_name verified_at aal ial])
            end

            it 'transliterates attributes to ASCII' do
              expect(get_asserted_attribute(user, :first_name)).to eq 'Jane'
            end
          end

          context 'Service Provider does not specify bundle' do
            context 'authn request does not specify bundle' do
              it 'only returns uuid, verified_at, aal, and ial' do
                expect(user.asserted_attributes.keys).to eq %i[uuid verified_at aal ial]
              end
            end

            context 'authn request specifies bundle' do
              # rubocop:disable Layout/LineLength
              let(:authn_context) do
                [
                  ial_value,
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name:last_name email, ssn",
                  "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}phone",
                ]
              end
              # rubocop:enable Layout/LineLength

              it 'uses authn request bundle' do
                expect(user.asserted_attributes.keys)
                  .to eq(%i[uuid email first_name last_name ssn phone verified_at aal ial])
              end
            end
          end

          context 'Service Provider specifies empty bundle' do
            let(:attribute_bundle) { [] }

            it 'only includes uuid, verified_at, aal, and ial' do
              expect(user.asserted_attributes.keys).to eq(%i[uuid verified_at aal ial])
            end
          end

          context 'custom bundle has invalid attribute name' do
            let(:attribute_bundle) { %w[email foo] }

            it 'silently skips invalid attribute name' do
              expect(user.asserted_attributes.keys).to eq(%i[uuid email verified_at aal ial])
            end
          end

          context 'x509 attributes included in the SP attribute bundle' do
            let(:attribute_bundle) do
              %w[email x509_subject x509_issuer x509_presented]
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
                expected = %i[uuid email verified_at aal ial x509_subject x509_issuer
                              x509_presented]
                expect(user.asserted_attributes.keys).to eq expected
              end
            end
          end
        end

        context 'when the user has been proofed with facial match' do
          let(:user) { create(:profile, :active, :verified, idv_level: :in_person).user }

          it 'sets aal attribute to IAL2' do
            expected_ial = Saml::Idp::Constants::IAL_VERIFIED_ACR
            expect(get_asserted_attribute(user, :ial)).to eq expected_ial
          end
        end
      end
    end

    context 'verified user and proofing VTR request' do
      let(:authn_context) { 'C1.C2.P1' }
      let(:attribute_bundle) { %w[email first_name last_name] }
      before do
        user.identities << identity
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
      before do
        user.identities << identity
        subject.build
      end

      context 'when the user has been proofed without facial match comparison' do
        context 'custom bundle includes email, phone, and first_name' do
          let(:attribute_bundle) { %w[email phone first_name] }

          it 'only includes uuid, email, aal, and ial (no verified_at)' do
            expect(user.asserted_attributes.keys).to eq %i[uuid email aal ial]
          end

          it 'does not create a getter function for IAL1 attributes' do
            expect(get_asserted_attribute(user, :email)).to eq user.last_sign_in_email_address.email
          end

          it 'gets UUID from Service Provider' do
            uuid_getter = user.asserted_attributes[:uuid][:getter]
            expect(uuid_getter.call(user)).to eq user.last_identity.uuid
          end
        end

        context 'custom bundle includes verified_at' do
          let(:attribute_bundle) { %w[email verified_at] }

          context 'the service provider is ial1' do
            let(:service_provider_ial) { 1 }

            it 'only includes uuid, email, aal, and ial (no verified_at)' do
              expect(user.asserted_attributes.keys).to eq %i[uuid email aal ial]
            end

            it 'does not create a getter function for IAL1 attributes' do
              expect(get_asserted_attribute(user, :email))
                .to eq user.last_sign_in_email_address.email
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
          let(:attribute_bundle) { [] }

          it 'only includes UUID, aal, and ial' do
            expect(user.asserted_attributes.keys).to eq(%i[uuid aal ial])
          end
        end

        context 'custom bundle has invalid attribute name' do
          let(:attribute_bundle) { %w[email foo] }

          it 'silently skips invalid attribute name' do
            expect(user.asserted_attributes.keys).to eq(%i[uuid email aal ial])
          end
        end

        context 'x509 attributes included in the SP attribute bundle' do
          let(:attribute_bundle) { %w[email x509_subject x509_issuer x509_presented] }

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
          let(:attribute_bundle) { %w[email] }

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

        it 'sets aal attribute to IAL1' do
          expected_ial = Saml::Idp::Constants::IAL_AUTH_ONLY_ACR
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    context 'verified user and IAL1 AAL3 request' do
      let(:attribute_bundle) { %w[email phone first_name] }

      before do
        user.identities << identity
        subject.build
      end

      context 'service provider configured for AAL3' do
        let(:service_provider_aal) { 3 }
        let(:authn_context) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'sets aal attribute to AAL2 with phishing resistance' do
          expect(
            get_asserted_attribute(
              user,
              :aal,
            ),
          ).to eq Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
        end

        it 'tracks the mismatch' do
          expect(fake_analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value:
              Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when service provider requests AAL3' do
        let(:authn_context) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'sets aal attribute to AAL3' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value:
              Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
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

        it 'sets aal attribute to IAL1' do
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
        let(:attribute_bundle) { %w[email phone first_name] }
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
          ServiceProvider.find_by(issuer: sp1_issuer).update!(ial: 2)
          subject.build
        end

        it 'sets aal attribute to IAL2' do
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
      let(:attribute_bundle) { %w[email phone first_name] }
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
        ServiceProvider.find_by(issuer: sp1_issuer).update!(ial: 1)
        subject.build
      end

      it 'sets aal attribute to IAL1' do
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

      before do
        user.identities << identity
        subject.build
      end

      context 'when the user has been proofed with facial match' do
        let(:user) { facial_match_verified_user }

        it 'sets aal attribute to IAL2 with facial match comparison' do
          expected_ial = Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end

      context 'when the user has been proofed without facial match' do
        it 'sets aal attribute to IAL2 (without facial match comparison)' do
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

        it 'sets aal attribute to IAL2 with facial match comparison' do
          expected_ial = Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
          expect(get_asserted_attribute(user, :ial)).to eq expected_ial
        end
      end
    end

    shared_examples 'unverified user' do
      let(:user) { create(:user, :fully_registered) }
      let(:attribute_bundle) { %w[first_name last_name] }

      context 'custom bundle does not include email, phone' do
        before do
          subject.build
        end

        it 'only includes UUID, aal, and ial' do
          expect(user.asserted_attributes.keys).to eq(%i[uuid aal ial])
        end
      end

      context 'custom bundle includes all_emails' do
        let(:attribute_bundle) { %w[all_emails] }
        before do
          create(:email_address, user: user)
          subject.build
        end

        it 'includes all the user email addresses' do
          all_emails_getter = user.asserted_attributes[:all_emails][:getter]
          emails = all_emails_getter.call(user)
          expect(emails.length).to eq(2)
          expect(emails).to match_array(user.confirmed_email_addresses.map(&:email))
        end
      end

      context 'custom bundle includes locale' do
        let(:attribute_bundle) { %w[locale] }
        before do
          subject.build
        end

        it 'includes the user locale' do
          locale_getter = user.asserted_attributes[:locale][:getter]
          locale = locale_getter.call(user)
          expect(locale).to eq('en')
        end
      end

      context 'custom bundle includes email, phone' do
        let(:attribute_bundle) { %w[first_name last_name email phone] }
        before do
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
      let(:attribute_bundle) { %w[email phone first_name] }
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
        create(:email_address, user:, email: 'email@example.com')

        ident = user.identities.last
        ident.email_address_id = user.email_addresses.first.id
        ident.save
        subject.build

        user.email_addresses.first.delete

        subject.build
      end

      it 'defers to user alternate email' do
        expect(get_asserted_attribute(user, :email))
          .to eq 'email@example.com'
      end
    end

    context 'with a nil email id' do
      let(:attribute_bundle) { %w[email phone first_name] }
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

        ident = user.identities.last
        ident.email_address_id = nil
        ident.save
        subject.build
      end

      it 'defers to user alternate email' do
        expect(get_asserted_attribute(user, :email))
          .to eq user.email_addresses.last.email
      end
    end

    context 'select email to send to partner feature is disabled' do
      let(:attribute_bundle) { %w[first_name last_name email phone] }

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
          create(:email_address, user:, email: 'email@example.com')

          ident = user.identities.last
          ident.email_address_id = user.email_addresses.first.id
          ident.save
          subject.build

          user.email_addresses.first.delete

          subject.build
        end

        it 'defers to user alternate email' do
          expect(get_asserted_attribute(user, :email))
            .to eq 'email@example.com'
        end
      end

      context 'with a nil email id' do
        let(:attribute_bundle) { %w[first_name email phone] }
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

          ident = user.identities.last
          ident.email_address_id = nil
          ident.save
          subject.build
        end

        it 'defers to user alternate email' do
          expect(get_asserted_attribute(user, :email))
            .to eq user.email_addresses.last.email
        end
      end
    end
  end

  describe 'aal attributes handling' do
    let(:attribute_bundle) { %w[email] }
    before do
      user.identities << identity
      subject.build
    end

    describe 'when no aal requested' do
      context 'default_aal is nil' do
        let(:authn_context) { [] }

        it 'sets aal attribute to default aal' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 1' do
        let(:service_provider_aal) { 1 }
        let(:authn_context) { [] }

        it 'sets aal attribute to aal1' do
          # we do not enforce aal1, we enforce default aal, so this should be updated
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 2' do
        let(:service_provider_aal) { 2 }
        let(:authn_context) { [] }

        it 'sets aal attribute to aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'default_aal is 3' do
        let(:service_provider_aal) { 3 }
        let(:authn_context) { [] }

        it 'sets aal attribute to aal3' do
          # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
          # so should be updated
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value:
              Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end
    end

    describe 'when aal is passed in via authn_context' do
      context 'aal1 is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF }

        # We do not support AAL1. when passed in, we enforce our default AAL value.
        # However, we are returning the AAL1 value, which is misleading.
        it 'sets aal attribute to aal1' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal2 is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }

        it 'sets aal attribute to plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'does not track a mismatch' do
          expect(@analytics).to_not have_logged_event(
            :asserted_aal_different_from_response_aal,
          )
        end
      end

      context 'aal2 with phishing-resistant mfa is requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF }

        # we should assert the more specific aal2 value
        it 'sets aal attribute to plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value:
              Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal2 with hspd12 mfa requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF }

        # we should assert the more specific aal2 value
        it 'sets aal attribute to plain aal2' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      # we need to deprecate AAL3 values, as we are not enforcing AAL3.
      context 'aal3 requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF }

        # when aal3 is requested, we are enforcing aal2 with phishing-resistant mfa.
        # we should update to assert that
        it 'sets aal attribute to plain aal3' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value:
              Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'aal3 with hspd12 mfa requested' do
        let(:authn_context) { Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF }

        # when aal3 is requested, we are enforcing aal2 with HSPD12 mfa.
        # we should update to assert that
        it 'sets aal attribute to plain aal3' do
          expect(get_asserted_attribute(user, :aal)).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'tracks the mismatch' do
          expect(@analytics).to have_logged_event(
            :asserted_aal_different_from_response_aal,
            asserted_aal_value: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
            client_id: service_provider.issuer,
            response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
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

          it 'sets aal attribute to the default value' do
            expect(get_asserted_attribute(user, :aal)).to eq(
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            )
          end

          it 'does not track a mismatch' do
            expect(@analytics).to_not have_logged_event(
              :asserted_aal_different_from_response_aal,
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

          it 'sets aal attribute to the default aal value' do
            # we don't assert aal1, so this should be the default aal value
            expect(get_asserted_attribute(user, :aal)).to eq(
              Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
            )
          end

          it 'tracks the mismatch' do
            expect(@analytics).to have_logged_event(
              :asserted_aal_different_from_response_aal,
              asserted_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              client_id: service_provider.issuer,
              response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
            )
          end
        end

        context 'aal2 is first' do
          let(:authn_context) do
            [
              Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            ]
          end

          it 'sets aal attribute to the aal2 value' do
            expect(get_asserted_attribute(user, :aal)).to eq(
              Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            )
          end

          it 'does not track a mismatch' do
            expect(@analytics).to_not have_logged_event(
              :asserted_aal_different_from_response_aal,
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
            it 'sets aal attribute to default aal' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'does not track a mismatch' do
              expect(@analytics).to_not have_logged_event(
                :asserted_aal_different_from_response_aal,
              )
            end
          end

          context 'default_aal is 1' do
            let(:service_provider_aal) { 1 }

            it 'sets aal attribute to aal1' do
              # we don't really have an aal1 level to enforce, so this should be updated
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 2' do
            let(:service_provider_aal) { 2 }

            it 'sets aal attribute to aal2' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'does not track a mismatch' do
              expect(@analytics).to_not have_logged_event(
                :asserted_aal_different_from_response_aal,
              )
            end
          end

          context 'default_aal is 3' do
            let(:service_provider_aal) { 3 }

            it 'sets aal attribute to aal3' do
              # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value:
                  Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end
      end

      context 'identity-proofing is requested' do
        let(:authn_context) { [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF] }

        describe 'no aal is requested via authn_context' do
          context 'default_aal is nil' do
            it 'sets aal attribute to default aal' do
              # this should be upgraded to AAL2, as we enforce that on an identity-proofing request
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 1' do
            let(:service_provider_aal) { 1 }

            it 'sets aal attribute to aal1' do
              # this should be upgraded to AAL2, as we enforce that on an identity-proofing request
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end

          context 'default_aal is 2' do
            let(:service_provider_aal) { 2 }

            it 'sets aal attribute to base aal2' do
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'does not tracks a mismatch' do
              expect(@analytics).to_not have_logged_event(
                :asserted_aal_different_from_response_aal,
              )
            end
          end

          context 'default_aal is 3' do
            let(:service_provider_aal) { 3 }

            it 'sets aal attribute to aal3' do
              # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value:
                  Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end

        describe 'multiple aal values are requested' do
          context 'default is first' do
            let(:authn_context) do
              [
                Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
              ]
            end

            it 'sets aal attribute to the default value' do
              # identity proofing enforces aal2, so that is what should be asserted
              expect(get_asserted_attribute(user, :aal)).to eq(
                Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end

            it 'tracks the mismatch' do
              expect(@analytics).to have_logged_event(
                :asserted_aal_different_from_response_aal,
                asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                client_id: service_provider.issuer,
                response_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              )
            end
          end
        end
      end

      context 'when ialmax is requested' do
        let(:options) do
          {
            authn_context: [
              Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
            ],
            authn_context_comparison: 'minimum',
          }
        end

        context 'with a non-verified user' do
          # remove any profiles
          before do
            user.profiles.delete_all
            subject.build
          end

          describe 'no aal is requested via authn_context' do
            context 'when default_aal is nil' do
              it 'sets aal attribute to default AAL' do
                # ialmax should assert aal2
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'when default_aal is 1' do
              let(:service_provider_aal) { 1 }

              it 'sets aal attribute to aal2 value' do
                # ialmax should assert aal2
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'when default_aal is 2' do
              let(:service_provider_aal) { 2 }

              it 'sets aal attribute to base aal2' do
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'does not track a mismatch' do
                expect(@analytics).to_not have_logged_event(
                  :asserted_aal_different_from_response_aal,
                )
              end
            end

            context 'when default_aal is 3' do
              let(:service_provider_aal) { 3 }

              it 'sets aal attribute to aal3' do
                # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value:
                    Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end
          end
        end

        context 'a verified user' do
          describe 'no AAL is requested via authn_context' do
            context 'when default_aal is nil' do
              it 'sets aal attribute to default AAL' do
                # this should be upgraded to AAL2, as we enforce that
                # on an identity-proofing request
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 1' do
              let(:service_provider_aal) { 1 }

              it 'sets aal attribute to aal1' do
                # this should be upgraded to AAL2, as we enforce that
                # on an identity-proofing request
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 2' do
              let(:service_provider_aal) { 2 }

              it 'sets aal attribute to base aal2' do
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
                )
              end
            end

            context 'default_aal is 3' do
              let(:service_provider_aal) { 3 }

              it 'sets aal attribute to aal3' do
                # we do not enforce aal3, we enforce aal2 with phishing-resistant mfa
                expect(get_asserted_attribute(user, :aal)).to eq(
                  Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
                )
              end

              it 'tracks the mismatch' do
                expect(@analytics).to have_logged_event(
                  :asserted_aal_different_from_response_aal,
                  asserted_aal_value:
                    Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
                  client_id: service_provider.issuer,
                  response_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
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
