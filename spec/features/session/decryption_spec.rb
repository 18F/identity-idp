require 'rails_helper'

RSpec.feature 'Session decryption' do
  context 'when there is a session decryption error' do
    it 'should raise an error and log the user out' do
      sign_in_and_2fa_user

      session_encryptor = Rails.application.config.session_options[:serializer]
      allow(session_encryptor).to receive(:load).and_raise(Encryption::EncryptionError)

      expect { visit account_path }.to raise_error(Encryption::EncryptionError)

      allow(session_encryptor).to receive(:load).and_call_original
      visit account_path

      # Should redirect to root since the user has been logged out
      expect(current_path).to eq(root_path)
    end
  end
end
