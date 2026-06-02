require 'rails_helper'

RSpec.describe AttemptsApi::Cacher do
  let(:user) { create(:user, :proofed) }
  let(:user_session) { {} }
  let(:password) { 'correct horse battery staple' }
  let(:encrypted_attempts_file_reference) { 'file-name' }
  let(:profile) { create(:profile, :active, encrypted_attempts_file_reference:) }
  subject(:cacher) { described_class.new(user, user_session) }
  let(:decrypted_events) do
    [
      { event_type: 'idv-event', jti: 'some-jti' },
      { event_type: 'idv-another-event', jti: 'another-jti' },
    ]
  end

  describe '#save' do
    before do
      allow(user).to receive(:active_profile).and_return(profile)
      allow(profile).to receive(:decrypt_user_proofing_events).with(password:).and_return(
        decrypted_events.to_json,
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
      it 'does not attempt to retrieve the events' do
        subject.save(password:)

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
