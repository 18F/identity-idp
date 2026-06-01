require 'rails_helper'

RSpec.describe AttemptsApi::Cacher do
  let(:user) { create(:user, :proofed) }
  let(:user_session) { {} }
  let(:password) { 'correct horse battery staple' }
  let(:encrypted_attempts_file_reference) { 'file-name' }
  let(:profile) { create(:profile, :active, encrypted_attempts_file_reference:) }
  let(:personal_key) { 'abcd efgh ijkl mno1' }
  subject(:cacher) { described_class.new(user, user_session) }
  let(:decrypted_events) do
    [
      { event_type: 'idv-event', jti: 'some-jti' },
      { event_type: 'idv-another-event', jti: 'another-jti' },
    ]
  end
  let(:returned_events) { decrypted_events.to_json }

  describe '#save' do
    before do
      allow(user).to receive(:active_profile).and_return(profile)
      allow(profile).to receive(:decrypt_user_proofing_events).with(password:).and_return(
        returned_events,
      )
    end

    it 'encrypts and saves proofing events in the session' do
      subject.save(password:)

      expect(user_session[:encrypted_proofing_events]).to be_present

      result = JSON.parse(
        SessionEncryptor.new.kms_decrypt(
          user_session[:encrypted_proofing_events],
        ),
      )
      expect(result).to eq(decrypted_events.as_json)
    end

    context 'profile does not have an encrypted_attempts_file_reference' do
      let(:encrypted_attempts_file_reference) { nil }

      context 'no decrypted events are returned' do
        let(:returned_events) { nil }
        it 'does not attempt to encrypt events' do
          expect { subject.save(password:) }.to_not raise_error

          expect(user_session[:encrypted_proofing_events]).to be_blank
        end
      end
    end
  end

  describe '#save_with_personal_key' do
    before do
      allow(user).to receive(:active_profile).and_return(profile)
      allow(profile).to receive(:recover_attempt_events).with(personal_key:).and_return(
        returned_events,
      )
    end

    it 'encrypts and saves proofing events in the session' do
      subject.save_with_personal_key(personal_key:)

      expect(user_session[:encrypted_proofing_events]).to be_present

      result = JSON.parse(
        SessionEncryptor.new.kms_decrypt(
          user_session[:encrypted_proofing_events],
        ),
      )
      expect(result).to eq(decrypted_events.as_json)
    end

    context 'no decrypted events are returned' do
      let(:returned_events) { nil }
      it 'does not attempt to encrypt events' do
        expect { subject.save_with_personal_key(personal_key:) }.to_not raise_error

        expect(user_session[:encrypted_proofing_events]).to be_blank
      end
    end
  end

  describe '#fetch' do
    context 'when there are no encrypted events in the session' do
      it 'returns nil' do
        expect(cacher.fetch).to be_nil
      end
    end

    context 'when there are encrypted events in the session' do
      let(:user_session) do
        {
          encrypted_proofing_events: SessionEncryptor.new.kms_encrypt(decrypted_events.to_json),
        }
      end
      it 'fetches and decrypts the events in the session' do
        expect(cacher.fetch).to eq(decrypted_events.as_json)
      end
    end
  end
end
