require 'rails_helper'

RSpec.describe Idv::HistoricalAttemptsConcern, type: :controller do
  let(:password) { ControllerHelper::VALID_PASSWORD }
  let(:registered_user) do
    create(
      :user,
      :fully_registered,
      password: password,
      email: 'email@example.com',
    )
  end
  let(:issuer) { 'this:is:a:test' }
  let(:sp) { create(:service_provider, ial: 2, issuer: issuer) }
  let(:profile) { create(:profile, :active, :verified )}
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }
  let(:user_proofing_event_mock) { double }
  let(:encryptor_mock) { double }
  let(:encrypted_events) do
    {
      'encrypted_data' => 'encrypted_test_data',
      'salt' => 'abcdef0123456789',
      'cost' => '000$0$0$',
    }
  end
  let(:idv_attempts) { { 'test_attempt' => 'some_data' } }

  controller ApplicationController do
    include Idv::HistoricalAttemptsConcern
  end

  before do
    sign_in(registered_user)

    allow(controller).to receive_messages(
      current_sp: sp,
      current_user: registered_user,
      sp_from_sp_session: sp,
      sp_session: { vtr: nil, acr_values: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF },
      user_session: { 'idv/attempts' => idv_attempts }
    )
    allow(registered_user).to receive_messages(
      active_profile: profile,
    )
    allow(IdentityConfig.store).to receive_messages(
      allowed_attempts_providers: [{ 'issuer' => sp.issuer }],
      attempts_api_enabled: true,
      historical_attempts_api_enabled: true,
    )

    allow(UserProofingEvent).to receive(:new).and_return(user_proofing_event_mock)
    allow(user_proofing_event_mock).to receive(:save).and_return(true)
    allow(UserProofingEvent).to receive(:save).and_return(true)
  end

  describe '#record_user_proofing_events' do
    subject(:record_user_proofing_events) {
      controller.record_user_proofing_events(password)
    }

    context 'historical_attempts_api_enabled is false at the secrets level' do
      before do
        allow(IdentityConfig.store).to receive(
          :historical_attempts_api_enabled,
        ).and_return(false)
      end

      it 'does not modify or create a UserProofingEvent' do
        record_user_proofing_events

        expect(UserProofingEvent).to_not have_received(:new)
        expect(UserProofingEvent).to_not have_received(:save)
      end
    end

    context 'service_provider is not an allowed_attempts_providers' do
      before do
        allow(IdentityConfig.store).to receive(
          :allowed_attempts_providers,
        ).and_return([])
      end

      it 'does not modify or create a UserProofingEvent' do
        record_user_proofing_events

        expect(UserProofingEvent).to_not have_received(:new)
        expect(UserProofingEvent).to_not have_received(:save)
      end
    end

    context 'when the user does not have an existing UserProofingEvent' do
      before do
        allow(Encryption::Encryptors::PiiEncryptor).to receive(:new).and_return(encryptor_mock)
        allow(encryptor_mock).to receive(:encrypt).and_return(encrypted_events.to_json)
        record_user_proofing_events
      end

      it 'creates and saves a UserProofingEvent' do
        expect(UserProofingEvent).to have_received(:new)
        expect(user_proofing_event_mock).to have_received(:save)
      end

      it 'includes the encrypted_events' do
        expect(UserProofingEvent).to have_received(:new).with(
          encrypted_events: encrypted_events.to_json,
          profile_id: registered_user.active_profile.id,
          service_providers_sent: [],
          cost: encrypted_events['cost'],
          salt: encrypted_events['salt'],
        )
      end
    end

    context 'when the user already has an existing UserProofingEvent' do
      let(:existing_events) { { 'old_attempt' => 'old_data' } }
      let(:pii_encryptor) { Encryption::Encryptors::PiiEncryptor.new(registered_user.password) }
      let(:encrypted_existing_events) do
        pii_encryptor.encrypt(existing_events.to_json, user_uuid: registered_user.uuid)
      end
      let(:concatenated_events) { existing_events.merge(idv_attempts) }
      let(:mock_user_proofing_event) { double }
      let(:user_proofing_event) {
        create(
          :user_proofing_event,
          encrypted_events: encrypted_existing_events,
          service_providers_sent: [sp.issuer],
          cost: JSON.parse(encrypted_existing_events)['cost'],
          salt: JSON.parse(encrypted_existing_events)['salt'],
          profile_id: registered_user.active_profile.id,
        )
      }

      before do
        allow(UserProofingEvent).to receive(:new).and_call_original
        allow(Encryption::Encryptors::PiiEncryptor).to receive(:new).and_return(pii_encryptor)
        allow(pii_encryptor).to receive(:decrypt).and_call_original
        allow(pii_encryptor).to receive(:encrypt).and_call_original
        allow(UserProofingEvent).to receive(:find_by).and_return(user_proofing_event)
        allow(user_proofing_event).to receive(:update_encrypted_events).and_return(true)
        record_user_proofing_events
      end

      it 'decrypts existing UserProofingEvent' do
        expect(pii_encryptor).to have_received(:decrypt).once
      end

      it 'encrypts concatenated data' do
        expect(pii_encryptor).to have_received(:encrypt).with(
          concatenated_events.to_json, user_uuid: registered_user.uuid
        )
      end

      it 'updates the UserProofingEvent with concatenated data' do
        expect(user_proofing_event).to have_received(:update_encrypted_events).once
      end
    end
  end
end
