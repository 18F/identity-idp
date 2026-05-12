require 'rails_helper'

RSpec.describe Idv::HistoricalAttemptsConcern, type: :controller do
  let(:password) { ControllerHelper::VALID_PASSWORD }
  let(:registered_user) do
    create(
      :user,
      :fully_registered,
      password:,
      email: 'email@example.com',
    )
  end
  let(:issuer) { 'this:is:a:test' }
  let(:sp) { create(:service_provider, ial: 2, issuer:) }
  let(:profile) { create(:profile, :active, :verified) }
  let(:idv_attempts) do
    [
      { 'idv-ssn-submitted' => { 'user_uuid' => registered_user.uuid } },
    ]
  end
  let(:allowed_attempts_providers) { [{ 'issuer' => sp.issuer }] }
  let(:pii_encryptor) { Encryption::Encryptors::PiiEncryptor.new(registered_user.password) }
  let(:encrypted_existing_events) do
    pii_encryptor.encrypt(idv_attempts.to_json, user_uuid: registered_user.uuid)
  end

  controller ApplicationController do
    include Idv::HistoricalAttemptsConcern
  end

  before do
    sign_in(registered_user)

    allow(controller).to receive_messages(
      current_sp: sp,
      current_user: registered_user,
      sp_from_sp_session: sp,
      sp_session: {
        acr_values: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
      },
      user_session: { 'idv/attempts' => idv_attempts },
    )
    allow(registered_user).to receive_messages(
      active_profile: profile,
    )
    allow(IdentityConfig.store).to receive_messages(
      allowed_attempts_providers:,
      attempts_api_enabled: true,
      historical_attempts_api_enabled: true,
    )
  end

  describe '#cache_user_proofing_events' do
    subject(:cache_user_proofing_events) do
      controller.cache_user_proofing_events(password)
    end

    let!(:user_proofing_event) do
      registered_user.active_profile.build_user_proofing_event(
        cost: JSON.parse(encrypted_existing_events)['cost'],
        salt: JSON.parse(encrypted_existing_events)['salt'],
      )
    end

    context 'historical_attempts_api_enabled feature flag is false' do
      before do
        allow(IdentityConfig.store).to receive(:historical_attempts_api_enabled).and_return(false)
        allow(profile).to receive(:decrypt_user_proofing_events)
      end

      it 'does not decrypt events' do
        expect(profile).to_not receive(:decrypt_user_proofing_events)

        cache_user_proofing_events
      end
    end

    context 'historical_attempts_api_enabled feature flag is true' do
      let(:mock_session_encryptor) { double }
      let(:kms_encrypted_events) { 'kms_encrypted_events' }

      before do
        allow(SessionEncryptor).to receive(:new).and_return(mock_session_encryptor)
        allow(mock_session_encryptor).to receive(:kms_encrypt).and_return(kms_encrypted_events)
        allow(profile).to receive(:decrypt_user_proofing_events).and_return(idv_attempts.to_json)
        cache_user_proofing_events
      end

      it 'decrypts the appropriate UserProofingEvent' do
        expect(profile).to have_received(:decrypt_user_proofing_events).once
      end

      it 'encrypts with the kms session key' do
        expect(mock_session_encryptor).to have_received(:kms_encrypt).once.with(
          idv_attempts.to_json,
        )
      end

      it 'updates the session with the UserProofingEvent' do
        expect(controller.user_session[:encrypted_proofing_events]).to eq(kms_encrypted_events)
      end

      context 'service_provider is not an allowed_attempts_providers' do
        before do
          allow(IdentityConfig.store).to receive(:allowed_attempts_providers).and_return([])
        end

        it 'does not decrypt events' do
          expect(profile).to_not receive(:decrypt_user_proofing_events)

          cache_user_proofing_events
        end
      end

      context 'events already sent to SP' do
        let(:user_proofing_event) do
          registered_user.active_profile.build_user_proofing_event(
            cost: JSON.parse(encrypted_existing_events)['cost'],
            salt: JSON.parse(encrypted_existing_events)['salt'],
            service_provider_ids_sent: [sp.id],
          )
        end

        it 'does not decrypt events' do
          expect(profile).to_not receive(:decrypt_user_proofing_events)

          cache_user_proofing_events
        end
      end

      context 'when no UserProofingEvent exists for the profile' do
        let(:user_proofing_event) { nil }

        it 'does not raise an error' do
          expect { cache_user_proofing_events }.to_not raise_error
        end
      end
    end
  end
end
