require 'rails_helper'

RSpec.describe UserProofingEvent, type: :model do
  let(:user_proofing_event) { create(:user_proofing_event, profile:) }
  let(:doc_retriever) { EncryptedDocStorage::AttemptDataHandler.new(s3_enabled: false) }
  let(:doc_writer) { EncryptedDocStorage::DocWriter.new(s3_enabled: false) }
  let(:attempt_events) { [{ event_type: 'idv-something' }, { event_type: 'idv-nothing-else' }] }
  let(:password) { 'password' }
  let(:personal_key) { 'personal-key' }
  let(:profile) { create(:profile, encrypted_attempts_file_reference: 'test-file-reference') }
  let(:personal_key_encrypted_events) do
    key_encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)
    key_encryptor.encrypt(attempt_events.to_json, user_uuid: profile.user.uuid)
  end
  let(:password_encrypted_events) do
    encryptor = Encryption::Encryptors::PiiEncryptor.new(password)
    encryptor.encrypt(attempt_events.to_json, user_uuid: profile.user.uuid)
  end

  let(:stored_event_data) do
    {
      password_encrypted_events:,
      personal_key_encrypted_events:,
    }.to_json
  end

  describe '#add_sp_sent' do
    let(:sp) { create(:service_provider) }

    before do
      user_proofing_event.add_sp_sent(sp.id)
    end

    it 'should add a given id to the list of service_provider_ids_sent' do
      expect(user_proofing_event.service_provider_ids_sent).to eq([sp.id])
    end

    it 'should be idempotent' do
      expect(user_proofing_event.service_provider_ids_sent.length).to eq(1)

      user_proofing_event.add_sp_sent(sp.id)

      expect(user_proofing_event.service_provider_ids_sent).to eq([sp.id])
    end
  end

  describe '#already_sent_to_sp?' do
    let(:sp) { create(:service_provider) }

    context 'when the given id is in the list of service_provider_ids_sent' do
      before do
        user_proofing_event.add_sp_sent(sp.id)
      end

      it 'should return true' do
        expect(user_proofing_event.already_sent_to_sp?(sp.id)).to eq(true)
      end
    end

    context 'when the given id is not in the list of service_provider_ids_sent' do
      it 'should return false' do
        expect(user_proofing_event.already_sent_to_sp?(sp.id)).to eq(false)
      end
    end
  end

  describe '#write_events' do
    before do
      allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(doc_writer)
      allow(doc_writer).to receive(:write_encrypted_attempt_events)
    end

    it 'encrypts and writes the events to storage' do
      expect(doc_writer).to receive(:write_encrypted_attempt_events).with(
        file_path: "#{profile.user.uuid}/#{profile.id}",
        encrypted_attempt_events: instance_of(String),
        name: 'test-file-reference',
      )

      user_proofing_event.write_events(password:, attempt_events:, personal_key:)
    end
  end

  describe '#decrypt_events' do
    let(:attempt_events) { [{ event_type: 'idv-something' }, { event_type: 'idv-nothing-else' }] }

    before do
      allow(EncryptedDocStorage::AttemptDataHandler).to receive(:new).and_return(doc_retriever)
      allow(doc_retriever).to receive(:retrieve_user_proofing_events).and_return(stored_event_data)
    end

    it 'retrieves and decrypts the events from storage' do
      expect(user_proofing_event.decrypt_events(password:)).to eq(attempt_events.to_json)

      expect(doc_retriever).to have_received(:retrieve_user_proofing_events).with(
        file_path: "#{profile.user.uuid}/#{profile.id}",
        file_name: 'test-file-reference',
      )
    end

    context 'when there is no data retrieved' do
      before do
        allow(doc_retriever).to receive(:retrieve_user_proofing_events).and_return(nil)
      end

      it 'returns an empty JSON object' do
        expect(user_proofing_event.decrypt_events(password:)).to be nil

        expect(doc_retriever).to have_received(:retrieve_user_proofing_events).with(
          file_path: "#{profile.user.uuid}/#{profile.id}",
          file_name: 'test-file-reference',
        )
      end
    end
  end

  describe '#reencrypt_recovery_attempts_data' do
    let(:new_personal_key) { 'new-personal-key' }

    before do
      allow(EncryptedDocStorage::AttemptDataHandler).to receive(:new).and_return(doc_retriever)
      allow(EncryptedDocStorage::DocWriter).to receive(:new).and_return(doc_writer)

      allow(doc_retriever).to receive(:retrieve_user_proofing_events).and_return(stored_event_data)
      allow(doc_writer).to receive(:write_encrypted_attempt_events)
    end

    it 'retrieves and decrypts the events from storage' do
      expect(doc_retriever).to receive(:retrieve_user_proofing_events).with(
        file_path: "#{profile.user.uuid}/#{profile.id}",
        file_name: 'test-file-reference',
      ).and_return(stored_event_data)

      # using `satisfy` is not ideal but i wanted this spec to test that
      # the password_encrypted_events don't change while the personal_key_encrypted
      # events do
      expect(doc_writer).to receive(:write_encrypted_attempt_events).with(
        file_path: "#{profile.user.uuid}/#{profile.id}",
        encrypted_attempt_events: satisfy do |arg|
          JSON.parse(arg)['password_encrypted_events'] == password_encrypted_events &&
          JSON.parse(arg)['personal_key_encrypted_events'] != personal_key_encrypted_events
        end,
        name: 'test-file-reference',
      )

      user_proofing_event.reencrypt_recovery_attempts_data(
        attempt_events:,
        personal_key: new_personal_key,
      )
    end
  end

  context 'round-trip specs' do
    let(:normalizer) { PersonalKeyGenerator.new(profile.user) }
    after do
      path = Rails.root.join(
        'tmp',
        'encrypted_attempt_events',
        'attempt_events',
        profile.user.uuid.to_s,
      )
      # cleanup
      FileUtils.rm_rf(path) if Dir.exist?(path)
    end

    describe '#decrypt_events' do
      it 'retrieves and decrypts the events from storage' do
        user_proofing_event.write_events(
          attempt_events:, password:,
          personal_key: normalizer.normalize(personal_key)
        )
        expect(user_proofing_event.decrypt_events(password:)).to eq(attempt_events.to_json)
      end
    end

    describe '#reencrypting with personal key' do
      let(:new_personal_key) { 'new-personal-key' }

      context 'with stored data' do
        before do
          user_proofing_event.write_events(attempt_events:, password:, personal_key:)
          user_proofing_event.reencrypt_recovery_attempts_data(
            attempt_events:,
            personal_key: new_personal_key,
          )
        end
        it 'reencrypts the events in storage so they are recoverable with the new key' do
          expect(
            user_proofing_event.recover_attempt_events(personal_key: new_personal_key),
          ).to eq(attempt_events.to_json)
        end
      end

      context 'if stored data does not exist' do
        # This method is only called if event data is cached in the session
        # If the session data exists but stored data does not, something is weird.
        it 'crashes on reencryption because that is a bad state' do
          expect do
            user_proofing_event.reencrypt_recovery_attempts_data(
              attempt_events:,
              personal_key:,
            )
          end.to raise_error NoMethodError, "undefined method 'merge' for nil"
        end
      end
    end
  end
end
