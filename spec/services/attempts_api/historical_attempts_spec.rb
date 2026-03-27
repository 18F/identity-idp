require 'rails_helper'

RSpec.describe AttemptsApi::HistoricalAttempts do
  let(:user) do
    create(
      :user,
      :fully_registered,
      password: ControllerHelper::VALID_PASSWORD,
      email: 'email@example.com',
    )
  end
  let(:issuer) { 'this:is:a:test' }
  let(:sp) { create(:service_provider, ial: 2, issuer: issuer) }
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
  let(:user_session) do
    {
      'idv/attempts' => {
        'test_attempt' => 'some_data',
      },
    }
  end
  let(:idv_session) do
    Idv::Session.new(
      user_session: user_session,
      current_user: user,
      service_provider: sp,
    )
  end

  subject do
    idv_session.applicant = applicant.merge({ 'uuid' => user.uuid })
    idv_session.create_profile_from_applicant_with_password(
      user.password,
      is_enhanced_ipp: false,
      proofing_components: applicant,
    )

    described_class.new(
      password: user.password,
      user_session: user_session,
      idv_session: idv_session,
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      allowed_attempts_providers: [{ 'issuer' => sp.issuer }],
      attempts_api_enabled: true,
      historical_attempts_api_enabled: true,
    )

    allow(UserProofingEvent).to receive(:new).and_return(user_proofing_event_mock)
    allow(user_proofing_event_mock).to receive(:save).and_return(true)
    allow(UserProofingEvent).to receive(:save).and_return(true)
  end

  describe '#record_events' do
    context 'historical_attempts_api_enabled is false at the secrets level' do
      before do
        allow(IdentityConfig.store).to receive(
          :historical_attempts_api_enabled,
        ).and_return(false)
      end

      it 'does not modify or create a UserProofingEvent' do
        subject.record_events

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
        subject.record_events

        expect(UserProofingEvent).to_not have_received(:new)
        expect(UserProofingEvent).to_not have_received(:save)
      end
    end

    context 'when the user does not have an existing UserProofingEvent' do
      before do
        allow(Encryption::Encryptors::PiiEncryptor).to receive(:new).and_return(encryptor_mock)
        allow(encryptor_mock).to receive(:encrypt).and_return(encrypted_events.to_json)
        subject.record_events
      end

      it 'creates and saves a UserProofingEvent' do
        expect(UserProofingEvent).to have_received(:new)
        expect(user_proofing_event_mock).to have_received(:save)
      end

      it 'includes the encrypted_events' do
        expect(UserProofingEvent).to have_received(:new).with(
          encrypted_events: encrypted_events.to_json,
          profile_id: idv_session.profile.id,
          service_providers_sent: [],
          cost: encrypted_events['cost'],
          salt: encrypted_events['salt'],
        )
      end
    end

    context 'when the user already has an existing UserProofingEvent' do
      let(:existing_events) { { 'old_attempt' => 'old_data' } }
      let(:pii_encryptor) { Encryption::Encryptors::PiiEncryptor.new(user.password) }
      let(:encrypted_existing_events) do
        pii_encryptor.encrypt(existing_events.to_json, user_uuid: user.uuid)
      end
      let(:concatenated_events) { existing_events.merge(user_session['idv/attempts']) }
      let(:mock_user_proofing_event) { double }
      user_proofing_event = nil

      before do
        subject # this is required to associate a profile with the idv_session
        allow(UserProofingEvent).to receive(:new).and_call_original
        allow(Encryption::Encryptors::PiiEncryptor).to receive(:new).and_return(pii_encryptor)
        allow(pii_encryptor).to receive(:decrypt).and_call_original
        allow(pii_encryptor).to receive(:encrypt).and_call_original
        user_proofing_event = create(
          :user_proofing_event,
          encrypted_events: encrypted_existing_events,
          service_providers_sent: [sp.issuer],
          cost: JSON.parse(encrypted_existing_events)['cost'],
          salt: JSON.parse(encrypted_existing_events)['salt'],
          profile_id: idv_session.profile.id,
        )
        allow(UserProofingEvent).to receive(:find_by).and_return(user_proofing_event)
        allow(user_proofing_event).to receive(:update_encrypted_events).and_return(true)
        subject.record_events
      end

      it 'decrypts existing UserProofingEvent' do
        expect(pii_encryptor).to have_received(:decrypt).once
      end

      it 'encrypts concatenated data' do
        expect(pii_encryptor).to have_received(:encrypt).with(
          concatenated_events.to_json, user_uuid: user.uuid
        )
      end

      it 'updates the UserProofingEvent with concatenated data' do
        expect(user_proofing_event).to have_received(:update_encrypted_events).once
      end
    end
  end
end
