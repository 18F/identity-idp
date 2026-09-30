require 'rails_helper'

RSpec.describe OpenidConnectTokenExchangeForm do
  subject(:form) { described_class.new(params) }

  let(:user) { create(:user, :proofed) }
  let(:broker_sp) { create(:service_provider, :active, issuer: 'broker.gov') }
  let(:target_sp) do
    create(
      :service_provider, :active,
      issuer: 'target.gov',
      ial: 2,
      attribute_bundle: %w[email],
      allowed_token_exchange_brokers: ['broker.gov']
    )
  end
  let(:rails_session_id) { SecureRandom.uuid }

  let(:broker_identity) do
    create(
      :service_provider_identity,
      user: user,
      service_provider: broker_sp.issuer,
      access_token: SecureRandom.urlsafe_base64,
      rails_session_id: rails_session_id,
      ial: broker_ial,
      verified_attributes: %w[email],
      scope: 'openid email token_exchange',
      token_exchange_consent_at: consent_at,
    )
  end
  let(:broker_ial) { Idp::Constants::IAL2 }
  let(:consent_at) { Time.zone.now }

  let(:params) do
    {
      grant_type: OpenidConnectTokenExchangeForm::TOKEN_EXCHANGE_GRANT_TYPE,
      subject_token: broker_identity.access_token,
      subject_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE,
      audience: target_sp.issuer,
    }
  end

  before do
    broker_sp
    target_sp
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
      .and_return(['broker.gov'])
    allow(TokenExchangeManifest).to receive(:allowed_targets)
      .with('broker.gov').and_return(['target.gov'])
    OutOfBandSessionAccessor.new(rails_session_id).put_empty_user_session
  end

  describe '#submit' do
    context 'happy path' do
      it 'succeeds and mints a target identity reusing the broker session' do
        result = form.submit

        expect(result.success?).to eq(true)
        minted = user.identities.find_by(service_provider: 'target.gov')
        expect(minted).to be_present
        expect(minted.rails_session_id).to eq(rails_session_id)
        expect(minted.last_consented_at).to be_present
        expect(minted.access_token).to be_present
        expect(minted.uuid).not_to eq(broker_identity.uuid)
      end

      it 'returns an RFC 8693 token-exchange response tagged with the broker' do
        response = form.response

        expect(response[:token_type]).to eq('Bearer')
        expect(response[:issued_token_type])
          .to eq(OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE)
        expect(response[:access_token]).to be_present
        expect(response[:exchanged_from]).to eq('broker.gov')
        expect(response[:expires_in]).to be > 0
      end

      it 'issues an id_token expressing delegation via the RFC 8693 act claim' do
        payload, = JWT.decode(form.response[:id_token], nil, false)

        expect(payload['act']).to eq('sub' => 'broker.gov')
        expect(payload['aud']).to eq('target.gov')
        expect(payload).not_to have_key('c_hash')
        expect(payload).not_to have_key('nonce')
        expect(payload['at_hash']).to be_present
      end
    end

    context 'RFC 8693 request parameter handling' do
      it 'rejects an unsupported requested_token_type with invalid_request' do
        form = described_class.new(
          params.merge(requested_token_type: 'urn:ietf:params:oauth:token-type:id_token'),
        )
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_request')
        expect(form.http_status).to eq(:bad_request)
      end

      it 'accepts an explicit access_token requested_token_type' do
        form = described_class.new(
          params.merge(requested_token_type: OpenidConnectTokenExchangeForm::ACCESS_TOKEN_TYPE),
        )
        expect(form.submit.success?).to eq(true)
      end

      it 'further narrows the issued scope to an explicitly requested scope' do
        broker_identity.update!(
          scope: 'openid email phone token_exchange',
          verified_attributes: %w[email phone],
        )
        target_sp.update!(attribute_bundle: %w[email phone])

        form = described_class.new(params.merge(scope: 'openid email'))
        expect(form.submit.success?).to eq(true)
        expect(form.response[:scope].split(' ')).to match_array(%w[openid email])
      end

      it 'never widens scope beyond what the broker holds, even if requested' do
        target_sp.update!(attribute_bundle: %w[email phone address])
        form = described_class.new(params.merge(scope: 'openid email phone address'))
        expect(form.submit.success?).to eq(true)
        expect(form.response[:scope].split(' ')).to match_array(%w[openid email])
      end
    end

    context 'RFC 8693 §2.2.2 error mapping' do
      it 'maps a policy-rejected subject token to invalid_request, not invalid_grant' do
        form = described_class.new(params.merge(subject_token: 'nope'))
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_request')
        expect(form.http_status).to eq(:bad_request)
      end

      it 'maps an unusable audience to invalid_target' do
        allow(TokenExchangeManifest).to receive(:allowed_targets)
          .with('broker.gov').and_return([])
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_target')
      end

      it 'refuses a broker exchanging for itself' do
        allow(TokenExchangeManifest).to receive(:allowed_targets)
          .with('broker.gov').and_return(['broker.gov'])
        form = described_class.new(params.merge(audience: 'broker.gov'))
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_target')
        expect(broker_identity.reload.access_token).to eq(params[:subject_token])
      end

      it 'describes only the highest-precedence error' do
        form = described_class.new(params.merge(grant_type: 'bogus', subject_token: 'nope'))
        expect(form.response[:error]).to eq('unsupported_grant_type')
        expect(form.response[:error_description]).not_to include('subject_token')
      end
    end

    context 'when an unauthorized token holder probes audiences' do
      let(:consent_at) { nil }
      let!(:revoked_target_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: target_sp.issuer,
          deleted_at: 1.day.ago,
        )
      end

      it 'reveals nothing about the target connection' do
        response = form.response
        expect(response[:error]).to eq('invalid_request')
        expect(response[:error_description]).not_to match(/target|revoked|in_use|forbids/)
        expect(form.errors.details[:audience]).to be_blank
      end
    end

    context 'when the broker SP is not an allow-listed broker' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_service_providers)
          .and_return([])
      end

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the capability is globally disabled' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      end

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the user never granted token-exchange consent' do
      let(:consent_at) { nil }

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the token-exchange consent has expired' do
      let(:consent_at) { (ServiceProviderIdentity::CONSENT_EXPIRATION + 1.day).ago }

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when audience is not on the broker allowlist' do
      before do
        allow(TokenExchangeManifest).to receive(:allowed_targets)
          .with('broker.gov').and_return(['other.gov'])
      end

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the target SP has not allow-listed the broker' do
      before { target_sp.update!(allowed_token_exchange_brokers: []) }

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the broker session is dead' do
      before { OutOfBandSessionAccessor.new(rails_session_id).destroy }

      it 'fails' do
        expect(form.submit.success?).to eq(false)
      end
    end

    context 'when subject_token is unknown' do
      let(:params) { super().merge(subject_token: 'nope') }

      it 'fails' do
        expect(form.submit.success?).to eq(false)
      end
    end

    context 'when subject_token_type is missing' do
      let(:params) { super().merge(subject_token_type: nil) }

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'IAL forwarding (no step-up)' do
      it 'forwards the broker IAL2 assertion to the minted identity' do
        expect(form.submit.success?).to eq(true)
        expect(user.identities.find_by(service_provider: 'target.gov').ial)
          .to eq(Idp::Constants::IAL2)
      end

      context 'when the broker token was asserted below IAL2' do
        let(:broker_ial) { Idp::Constants::IAL1 }

        it 'refuses to mint even though the user is proofed to IAL2' do
          expect(user.active_profile).to be_present
          expect(form.submit.success?).to eq(false)
          expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
        end
      end

      context 'when the broker token was asserted at IALMax for a verified user' do
        let(:broker_ial) { Idp::Constants::IAL_MAX }

        it 'treats it as IAL2 and mints' do
          expect(form.submit.success?).to eq(true)
          expect(user.identities.find_by(service_provider: 'target.gov')).to be_present
        end
      end

      context 'when the broker token has no asserted IAL (nil)' do
        let(:broker_ial) { nil }

        it 'refuses to mint (nil is not IAL2, despite nil.to_i == 0)' do
          expect(form.submit.success?).to eq(false)
          expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
        end
      end
    end

    context 'scope / attribute narrowing to the target SP' do
      let(:broker_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: broker_sp.issuer,
          access_token: SecureRandom.urlsafe_base64,
          rails_session_id: rails_session_id,
          ial: Idp::Constants::IAL2,
          verified_attributes: %w[email phone address],
          scope: 'openid email phone address token_exchange',
          token_exchange_consent_at: Time.zone.now,
        )
      end

      before do
        target_sp.update!(attribute_bundle: %w[email])
      end

      it 'grants the target only what its own attribute bundle allows' do
        expect(form.submit.success?).to eq(true)

        minted = user.identities.find_by(service_provider: 'target.gov')
        expect(minted.scope.split(' ')).to match_array(%w[openid email])
        expect(minted.verified_attributes).to eq(%w[email])
      end

      context 'with SP-facing bundle names (first_name, dob)' do
        let(:broker_identity) do
          create(
            :service_provider_identity,
            user: user,
            service_provider: broker_sp.issuer,
            access_token: SecureRandom.urlsafe_base64,
            rails_session_id: rails_session_id,
            ial: Idp::Constants::IAL2,
            verified_attributes: %w[email given_name birthdate phone],
            scope: 'openid email profile phone token_exchange',
            token_exchange_consent_at: Time.zone.now,
          )
        end

        before { target_sp.update!(attribute_bundle: %w[email first_name dob]) }

        it 'translates bundle names to claims and admits only fully-covered scopes' do
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          # The broker's `profile` authorizes birthdate, and the bundle names dob,
          # so the narrower profile:birthdate is granted. `profile` itself is
          # refused (it would also release family_name + verified_at), and phone
          # is outside the bundle.
          expect(minted.scope.split(' ')).to match_array(%w[openid email profile:birthdate])
          expect(minted.scope).not_to include('phone')
          expect(minted.verified_attributes).to match_array(%w[email birthdate])
        end
      end

      context 'when the broker holds the umbrella profile scope' do
        let(:broker_identity) do
          create(
            :service_provider_identity,
            user: user,
            service_provider: broker_sp.issuer,
            access_token: SecureRandom.urlsafe_base64,
            rails_session_id: rails_session_id,
            ial: Idp::Constants::IAL2,
            verified_attributes: %w[email given_name family_name birthdate verified_at],
            scope: 'openid email profile token_exchange',
            token_exchange_consent_at: Time.zone.now,
          )
        end

        it 'refuses profile for a target whose bundle only names first_name' do
          target_sp.update!(attribute_bundle: %w[email first_name])
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to match_array(%w[openid email])
          expect(minted.scope).not_to include('profile')
        end

        it 'grants profile only when the bundle covers every claim it releases' do
          target_sp.update!(attribute_bundle: %w[email first_name last_name dob verified_at])
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to include('profile')
        end

        it 'grants the narrower profile:name to a name-only target when the broker holds profile' do
          target_sp.update!(attribute_bundle: %w[email first_name last_name])
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to match_array(%w[openid email profile:name])
          expect(minted.verified_attributes).to match_array(%w[email given_name family_name])
        end
      end

      context 'when the target bundle uses the address component vocabulary' do
        let(:broker_identity) do
          create(
            :service_provider_identity,
            user: user,
            service_provider: broker_sp.issuer,
            access_token: SecureRandom.urlsafe_base64,
            rails_session_id: rails_session_id,
            ial: Idp::Constants::IAL2,
            verified_attributes: %w[email address],
            scope: 'openid email address token_exchange',
            token_exchange_consent_at: Time.zone.now,
          )
        end

        it 'maps address1/city/state/zipcode to the composite address claim' do
          target_sp.update!(attribute_bundle: %w[email address1 city state zipcode])
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to match_array(%w[openid email address])
          expect(minted.verified_attributes).to match_array(%w[email address])
        end
      end

      context 'when the broker holds an attribute it was never scoped for' do
        let(:broker_identity) do
          create(
            :service_provider_identity,
            user: user,
            service_provider: broker_sp.issuer,
            access_token: SecureRandom.urlsafe_base64,
            rails_session_id: rails_session_id,
            ial: Idp::Constants::IAL2,
            verified_attributes: %w[email social_security_number],
            scope: 'openid email token_exchange',
            token_exchange_consent_at: Time.zone.now,
          )
        end

        before { target_sp.update!(attribute_bundle: %w[email ssn]) }

        it 'does not store an attribute outside the granted scope' do
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to match_array(%w[openid email])
          expect(minted.verified_attributes).to eq(%w[email])
        end
      end
    end

    context 'minted identity hygiene' do
      it 'forwards aal, requested_aal_value and email_address_id from the broker' do
        email_address = user.confirmed_email_addresses.first
        broker_identity.update!(
          aal: 2,
          requested_aal_value: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          email_address_id: email_address.id,
        )
        expect(form.submit.success?).to eq(true)

        minted = user.identities.find_by(service_provider: 'target.gov')
        expect(minted.aal).to eq(2)
        expect(minted.requested_aal_value)
          .to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
        # verified_attributes includes plain `email`, so the model keeps the id.
        expect(minted.verified_attributes).to include('email')
        expect(minted.email_address_id).to eq(email_address.id)
      end

      it 'leaves no redeemable authorization code on the minted identity' do
        expect(form.submit.success?).to eq(true)
        expect(user.identities.find_by(service_provider: 'target.gov').session_uuid).to be_nil
      end
    end

    context 'when the presented broker token was not issued with token_exchange' do
      let(:broker_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: broker_sp.issuer,
          access_token: SecureRandom.urlsafe_base64,
          rails_session_id: rails_session_id,
          ial: Idp::Constants::IAL2,
          verified_attributes: %w[email],
          scope: 'openid email',
          token_exchange_consent_at: Time.zone.now,
        )
      end

      it 'fails even though a prior consent is recorded (consent travels with the grant)' do
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_request')
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the target SP is not entitled to identity proofing (IAL1)' do
      before { target_sp.update!(ial: 1) }

      it 'refuses to mint an IAL2 identity for it' do
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_target')
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the broker SP is no longer active' do
      before { broker_sp.update!(active: false) }

      it 'fails and mints nothing' do
        expect(form.submit.success?).to eq(false)
        expect(user.identities.find_by(service_provider: 'target.gov')).to be_nil
      end
    end

    context 'when the user previously revoked the target connection' do
      let!(:revoked_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: target_sp.issuer,
          verified_attributes: %w[email phone address],
          deleted_at: 1.day.ago,
        )
      end

      it 'refuses to silently revive it' do
        expect(form.submit.success?).to eq(false)
        expect(form.response[:error]).to eq('invalid_target')
        expect(revoked_identity.reload.deleted_at).to be_present
      end
    end

    context 'when a target identity exists with no bound session' do
      let!(:unbound_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: target_sp.issuer,
          rails_session_id: nil,
        )
      end

      it 'treats it as reusable rather than crashing' do
        expect { form.submit }.not_to raise_error
        expect(form.submit.success?).to eq(true)
      end
    end

    context 'when a live target identity already exists for a different session' do
      let!(:other_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: target_sp.issuer,
          access_token: 'existing-token',
          rails_session_id: SecureRandom.uuid,
          ial: Idp::Constants::IAL2,
        )
      end

      before do
        OutOfBandSessionAccessor.new(other_identity.rails_session_id).put_empty_user_session
      end

      it 'refuses to hijack it' do
        expect(form.submit.success?).to eq(false)
        expect(other_identity.reload.access_token).to eq('existing-token')
      end
    end
  end
end
