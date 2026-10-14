require 'rails_helper'

RSpec.describe DelegatedTokenClaims do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user, :proofed) }
  let(:agency) { create(:agency, name: 'Department of Housing Support') }
  let(:attribute_bundle) { %w[email first_name last_name] }
  let(:shareable_attributes) { [] }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency:, ial: 2, attribute_bundle:,
      delegation_sp_shareable_attributes: shareable_attributes
    )
  end
  let(:service_provider) { create(:service_provider, :delegation_service_provider) }
  let(:rails_session_id) { SecureRandom.hex }
  let(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      ial: 2, rails_session_id:, scope: 'openid email',
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR
    )
  end
  let(:ial) { Idp::Constants::IAL2 }
  let(:aal) { Idp::Constants::AAL2 }
  let(:pii) do
    {
      first_name: 'Ada',
      last_name: 'Lovelace',
      dob: '12/10/1815',
      ssn: '900-11-2222',
      address1: '12 Analytical Way',
      city: 'Washington',
      state: 'DC',
      zipcode: '20001',
      phone: '(202) 555-0100',
    }
  end

  subject(:claims) do
    described_class.new(
      user:, identity:, application:, ial:, aal:, sp_rails_session_id: rails_session_id,
    )
  end

  before do
    OutOfBandSessionAccessor.new(rails_session_id).put_pii(
      profile_id: user.active_profile.id, pii:, expiration: 300,
    )
  end

  describe '#agency_sub' do
    it 'creates the agency identifier when the person has never used the agency' do
      expect { claims.agency_sub }.to change { AgencyIdentity.where(user:, agency:).count }.by(1)
      expect(claims.agency_sub).to eq(AgencyIdentity.find_by(user:, agency:).uuid)
    end

    it 'creates no connection to the application' do
      claims.agency_sub
      expect(ServiceProviderIdentity.where(service_provider: application.issuer)).to be_empty
    end
  end

  describe '#agency_claims' do
    it 'releases the bundle in userinfo shape while the sign-in is live' do
      expect(claims.session_live?).to eq(true)
      expect(claims.agency_claims).to eq(
        email: identity.email_address_for_sharing.email,
        email_verified: true,
        given_name: 'Ada',
        family_name: 'Lovelace',
      )
    end

    context 'with a bundle naming one of the two names and address components' do
      let(:attribute_bundle) { %w[first_name address1 city dob] }

      it 'filters the names one at a time and releases the whole address claim' do
        result = claims.agency_claims
        expect(result).to include(given_name: 'Ada', birthdate: '1815-12-10')
        expect(result[:address]).to include(locality: 'Washington', postal_code: '20001')
        expect(result.keys).not_to include(:family_name, :phone, :social_security_number)
        expect(result[:email]).to be_present
      end
    end

    context 'once the sign-in has ended' do
      let(:attribute_bundle) { %w[email all_emails first_name ssn verified_at] }

      before { OutOfBandSessionAccessor.new(rails_session_id).destroy }

      it 'keeps only email and all_emails' do
        expect(claims.session_live?).to eq(false)
        expect(claims.agency_claims.keys).to contain_exactly(:email, :email_verified, :all_emails)
      end
    end

    context 'when the token was issued for a sign-in that was not identity-verified' do
      let(:ial) { Idp::Constants::IAL1 }

      it 'releases no proofed attribute' do
        expect(claims.agency_claims.keys).to contain_exactly(:email, :email_verified)
        expect(claims.acr).to eq(Saml::Idp::Constants::IAL_AUTH_ONLY_ACR)
      end
    end

    context 'when the bundle names PIV/CAC attributes' do
      let(:attribute_bundle) { %w[email x509_subject x509_issuer x509_presented] }

      it 'omits them for a person without PIV/CAC' do
        expect(claims.agency_claims.keys).not_to include(:x509_subject)
      end

      it 'carries them for a person signed in with PIV/CAC' do
        create(:piv_cac_configuration, user:)
        OutOfBandSessionAccessor.new(rails_session_id).put_x509(
          X509::Attributes.new_from_hash(subject: 'CN=Ada', issuer: 'CN=Issuer', presented: true),
          300,
        )
        expect(claims.agency_claims).to include(
          x509_subject: 'CN=Ada', x509_issuer: 'CN=Issuer', x509_presented: true,
        )
      end
    end

    context 'without a connection to the service provider' do
      let(:identity) { nil }

      it 'falls back to the account email' do
        expect(claims.agency_claims[:email]).to eq(user.last_sign_in_email_address.email)
      end
    end
  end

  describe '#shared_with_service_provider' do
    let(:shareable_attributes) { %w[first_name ssn] }

    it 'releases only what the application lists and itself receives' do
      expect(claims.shared_with_service_provider).to eq(given_name: 'Ada')
    end

    context 'when nothing is listed' do
      let(:shareable_attributes) { [] }

      it 'is empty' do
        expect(claims.shared_with_service_provider).to eq({})
      end
    end
  end

  describe '#acr and #aal_acr' do
    it 'uses the vocabulary userinfo uses' do
      expect(claims.acr).to eq(Saml::Idp::Constants::IAL_VERIFIED_ACR)
      expect(claims.aal_acr).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
    end

    context 'with no recorded authentication assurance' do
      let(:aal) { nil }

      it 'falls back to what the sign-in asserted, then the default' do
        expect(claims.aal_acr).to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        identity.update!(requested_aal_value: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF)
        expect(claims.aal_acr).to eq(Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF)
      end
    end
  end
end
