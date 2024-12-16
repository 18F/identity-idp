require 'rails_helper'

RSpec.describe OpenidConnectUserInfoPresenter do
  include Rails.application.routes.url_helpers

  let(:rails_session_id) { SecureRandom.uuid }
  let(:scope) do
    'openid email all_emails address phone profile social_security_number x509'
  end
  let(:service_provider_ial) { 2 }
  let(:service_provider) { create(:service_provider, ial: service_provider_ial) }
  let(:profile) { create(:profile, :active, :verified) }
  let(:vtr) { ['C1.C2.P1'] }
  let(:acr_values) { nil }
  let(:requested_aal_value) { nil }
  let(:identity) do
    build(
      :service_provider_identity,
      rails_session_id: rails_session_id,
      user: create(:user, profiles: [profile].compact),
      service_provider: service_provider.issuer,
      scope: scope,
      vtr: vtr,
      acr_values: acr_values,
      requested_aal_value: requested_aal_value,
    )
  end

  subject(:presenter) { OpenidConnectUserInfoPresenter.new(identity) }

  describe '#user_info' do
    let(:pii) do
      {
        first_name: 'John',
        last_name: 'Smith',
        dob: '12/31/1970',
        address1: '123 Fake St',
        address2: 'Apt 456',
        city: 'Washington',
        state: 'DC',
        zipcode: '  12345-1234',
        phone: '(703) 555-5555',
        ssn: '666661234',
      }
    end

    before do
      if pii.present?
        OutOfBandSessionAccessor.new(rails_session_id).put_pii(
          profile_id: profile.id,
          pii: pii,
          expiration: 5.minutes.in_seconds,
        )
      end
    end

    subject(:user_info) { presenter.user_info }

    context 'with a vtr parameter' do
      let(:acr_values) { nil }

      context 'no identity proofing' do
        let(:vtr) { ['C1.C2'] }
        let(:scope) { 'openid email all_emails' }

        it 'includes the correct attributes' do
          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info).to_not have_key(:ial)
            expect(user_info).to_not have_key(:aal)
            expect(user_info[:vot]).to eq('C1.C2')
          end
        end
      end

      context 'identity proofing' do
        let(:vtr) { ['C1.C2.P1'] }
        let(:scope) { 'openid email all_emails address phone profile social_security_number' }

        it 'includes the correct non-proofed attributes' do
          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info).to_not have_key(:ial)
            expect(user_info).to_not have_key(:aal)
            expect(user_info[:vot]).to eq('C1.C2.P1')
          end
        end

        it 'includes the proofed attributes' do
          aggregate_failures do
            expect(user_info[:given_name]).to eq('John')
            expect(user_info[:family_name]).to eq('Smith')
            expect(user_info[:birthdate]).to eq('1970-12-31')
            expect(user_info[:phone]).to eq('+17035555555')
            expect(user_info[:phone_verified]).to eq(true)
            expect(user_info[:address]).to eq(
              formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
              street_address: "123 Fake St\nApt 456",
              locality: 'Washington',
              region: 'DC',
              postal_code: '12345',
            )
            expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
            expect(user_info[:social_security_number]).to eq('666661234')
          end
        end
      end
    end

    context 'with ACR values' do
      let(:vtr) { nil }

      context 'no identity proofing' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end
        let(:requested_aal_value) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
        let(:scope) { 'openid email all_emails' }

        it 'includes the correct attributes' do
          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info[:ial]).to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
            expect(user_info[:aal]).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
            expect(user_info).to_not have_key(:vot)
          end
        end
      end

      context 'identity proofing' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end
        let(:requested_aal_value) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
        let(:scope) { 'openid email all_emails address phone profile social_security_number' }

        it 'includes the correct non-proofed attributes' do
          aggregate_failures do
            expect(user_info[:sub]).to eq(identity.uuid)
            expect(user_info[:iss]).to eq(root_url)
            expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
            expect(user_info[:email_verified]).to eq(true)
            expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
            expect(user_info[:ial]).to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
            expect(user_info[:aal]).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
            expect(user_info).to_not have_key(:vot)
          end
        end

        it 'includes the proofed attributes' do
          aggregate_failures do
            expect(user_info[:given_name]).to eq('John')
            expect(user_info[:family_name]).to eq('Smith')
            expect(user_info[:birthdate]).to eq('1970-12-31')
            expect(user_info[:phone]).to eq('+17035555555')
            expect(user_info[:phone_verified]).to eq(true)
            expect(user_info[:address]).to eq(
              formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
              street_address: "123 Fake St\nApt 456",
              locality: 'Washington',
              region: 'DC',
              postal_code: '12345',
            )
            expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
            expect(user_info[:social_security_number]).to eq('666661234')
          end
        end

        context 'with facial match comparison' do
          let(:acr_values) do
            [
              Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
            ].join(' ')
          end

          it 'includes the correct non-proofed attributes' do
            aggregate_failures do
              expect(user_info[:sub]).to eq(identity.uuid)
              expect(user_info[:iss]).to eq(root_url)
              expect(user_info[:email]).to eq(identity.user.email_addresses.first.email)
              expect(user_info[:email_verified]).to eq(true)
              expect(user_info[:all_emails]).to eq([identity.user.email_addresses.first.email])
              expect(user_info[:ial]).to eq(
                Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF,
              )
              expect(user_info[:aal]).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
              expect(user_info).to_not have_key(:vot)
            end
          end

          it 'includes the proofed attributes' do
            aggregate_failures do
              expect(user_info[:given_name]).to eq('John')
              expect(user_info[:family_name]).to eq('Smith')
              expect(user_info[:birthdate]).to eq('1970-12-31')
              expect(user_info[:phone]).to eq('+17035555555')
              expect(user_info[:phone_verified]).to eq(true)
              expect(user_info[:address]).to eq(
                formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
                street_address: "123 Fake St\nApt 456",
                locality: 'Washington',
                region: 'DC',
                postal_code: '12345',
              )
              expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
              expect(user_info[:social_security_number]).to eq('666661234')
            end
          end
        end
      end

      context 'IALMax' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end
        let(:requested_aal_value) { Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF }
        let(:scope) { 'openid email all_emails address phone profile social_security_number' }

        context 'the user has verified their identity' do
          it 'includes the proofed attributes' do
            aggregate_failures do
              expect(user_info[:ial]).to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
              expect(user_info[:aal]).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
              expect(user_info).to_not have_key(:vot)
              expect(user_info[:given_name]).to eq('John')
              expect(user_info[:family_name]).to eq('Smith')
              expect(user_info[:birthdate]).to eq('1970-12-31')
              expect(user_info[:phone]).to eq('+17035555555')
              expect(user_info[:phone_verified]).to eq(true)
              expect(user_info[:address]).to eq(
                formatted: "123 Fake St\nApt 456\nWashington, DC 12345",
                street_address: "123 Fake St\nApt 456",
                locality: 'Washington',
                region: 'DC',
                postal_code: '12345',
              )
              expect(user_info[:verified_at]).to eq(profile.verified_at.to_i)
              expect(user_info[:social_security_number]).to eq('666661234')
            end
          end
        end

        context 'the user has not verified their identity' do
          let(:pii) { nil }
          let(:profile) { nil }

          it 'does not include proofed attributes' do
            aggregate_failures do
              expect(user_info[:ial]).to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
              expect(user_info[:aal]).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
              expect(user_info).to_not have_key(:vot)
              expect(user_info).to_not have_key(:given_name)
              expect(user_info).to_not have_key(:family_name)
              expect(user_info).to_not have_key(:birthdate)
              expect(user_info).to_not have_key(:phone)
              expect(user_info).to_not have_key(:phone_verified)
              expect(user_info).to_not have_key(:address)
              expect(user_info).to_not have_key(:social_security_number)
            end
          end
        end
      end
    end

    context 'when minimal scopes are requested for proofed attributes' do
      let(:scope) do
        'openid email all_emails profile'
      end

      it 'only returns the requested attributes' do
        expect(user_info[:given_name]).to eq('John')
        expect(user_info[:family_name]).to eq('Smith')
        expect(user_info[:birthdate]).to eq('1970-12-31')
        expect(user_info).to_not have_key(:phone)
        expect(user_info).to_not have_key(:phone_verified)
        expect(user_info).to_not have_key(:address)
        expect(user_info).to_not have_key(:social_security_number)
      end
    end

    context 'when x509 scopes are requested' do
      let(:x509_subject) { 'x509-subject' }
      let(:x509_presented) { true }
      let(:x509_issuer) { 'trusted issuer' }
      let(:x509) do
        X509::Attributes.new_from_hash(
          subject: x509_subject,
          presented: x509_presented,
          issuer: x509_issuer,
        )
      end

      let(:scope) do
        'openid email x509'
      end

      let(:identity) do
        build(
          :service_provider_identity,
          rails_session_id: rails_session_id,
          user: create(:user, :with_piv_or_cac),
          scope: scope,
        )
      end

      context 'when the piv/cac was used as a second factor' do
        before do
          OutOfBandSessionAccessor.new(rails_session_id).put_x509(x509, 5.minutes.in_seconds)
        end

        it 'includes the x509 claims' do
          aggregate_failures do
            expect(user_info[:x509_subject]).to eq(x509_subject)
            expect(user_info[:x509_presented]).to eq(x509_presented)
            expect(user_info[:x509_issuer]).to eq(x509_issuer)
          end
        end
      end

      context 'when the piv/cac was not used as a second factor' do
        it 'includes blank x509 claims' do
          aggregate_failures do
            expect(user_info[:x509_subject]).to be_blank
            expect(user_info[:x509_issuer]).to be_blank
            expect(user_info[:x509_presented]).to be false
          end
        end
      end

      context 'when the user does not have an associated piv/cac' do
        let(:identity) do
          build(
            :service_provider_identity,
            rails_session_id: rails_session_id,
            user: create(:user, :fully_registered),
            scope: scope,
          )
        end

        it 'includes blank x509 claims' do
          aggregate_failures do
            expect(user_info[:x509_subject]).to be_blank
            expect(user_info[:x509_issuer]).to be_blank
            expect(user_info[:x509_presented]).to be false
          end
        end
      end
    end

    context 'with a deleted email' do
      let(:identity) do
        build(
          :service_provider_identity,
          rails_session_id: rails_session_id,
          user: create(:user, :fully_registered, :with_multiple_emails),
          scope: scope,
        )
      end

      before do
        identity.email_address_id = identity.user.email_addresses.first.id
        identity.user.email_addresses.first.delete
      end

      it 'defers to user alternate email' do
        expect(identity.user.reload.email_addresses.first.id)
          .to_not eq(identity.email_address_id)
        expect(identity.user.reload.email_addresses.count).to be 1
        expect(user_info[:email]).to eq(identity.user.email_addresses.last.email)
      end
    end

    context 'with nil email id' do
      let(:identity) do
        build(
          :service_provider_identity,
          rails_session_id: rails_session_id,
          user: create(:user, :fully_registered),
          scope: scope,
        )
      end

      before do
        identity.email_address_id = nil
      end

      it 'adds the signed in email id to the identity' do
        expect(user_info[:email]).to eq(identity.user.email_addresses.last.email)
      end
    end
  end
end
