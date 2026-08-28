require 'rails_helper'

RSpec.describe OpenidConnectTokenExchangeForm do
  subject(:form) { described_class.new(params) }

  let(:user) { create(:user, :proofed) }
  let(:broker_sp) { create(:service_provider, issuer: 'broker.gov') }
  let(:target_sp) { create(:service_provider, :active, issuer: 'target.gov') }
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
      scope: 'openid email',
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
          scope: 'openid email phone address',
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
            verified_attributes: %w[email first_name dob phone],
            scope: 'openid email profile phone',
            token_exchange_consent_at: Time.zone.now,
          )
        end

        before { target_sp.update!(attribute_bundle: %w[email first_name dob]) }

        it 'translates bundle names to claims and keeps only their scopes' do
          expect(form.submit.success?).to eq(true)

          minted = user.identities.find_by(service_provider: 'target.gov')
          expect(minted.scope.split(' ')).to match_array(%w[openid email profile])
          expect(minted.scope).not_to include('phone')
          expect(minted.verified_attributes).to match_array(%w[email first_name dob])
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
            verified_attributes: %w[email ssn],
            scope: 'openid email',
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

    context 'when a revived deleted target identity held broader attributes' do
      let!(:stale_identity) do
        create(
          :service_provider_identity,
          user: user,
          service_provider: target_sp.issuer,
          verified_attributes: %w[email phone address],
          deleted_at: 1.day.ago,
        )
      end

      before { target_sp.update!(attribute_bundle: %w[email]) }

      it 'forces the narrowed set rather than unioning the stale one' do
        expect(form.submit.success?).to eq(true)
        expect(stale_identity.reload.verified_attributes).to eq(%w[email])
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
