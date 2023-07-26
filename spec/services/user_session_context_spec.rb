require 'rails_helper'

RSpec.describe UserSessionContext do
  let(:session) { {} }
  describe '.authentication_context?' do
    it 'returns true when context is default context' do
      UserSessionContext.set_authentication_context!(session)

      expect(UserSessionContext.authentication_context?(session)).to eq true
    end

    it 'returns false when context is not default context' do
      UserSessionContext.set_confirmation_context!(session)
      expect(UserSessionContext.authentication_context?(session)).to eq false

      UserSessionContext.set_reauthentication_context!(session)
      expect(UserSessionContext.authentication_context?(session)).to eq false
    end
  end

  describe '.reauthentication_context?' do
    it 'returns true when context is reauthn context' do
      UserSessionContext.set_reauthentication_context!(session)

      expect(UserSessionContext.reauthentication_context?(session)).to eq true
    end

    it 'returns false when context is default context' do
      UserSessionContext.set_authentication_context!(session)
      expect(UserSessionContext.reauthentication_context?(session)).to eq false
    end
  end

  describe '.authentication_or_reauthentication_context?' do
    it 'returns true when context is default or reauth context' do
      UserSessionContext.set_authentication_context!(session)
      expect(UserSessionContext.authentication_or_reauthentication_context?(session)).to eq true

      UserSessionContext.set_reauthentication_context!(session)
      expect(UserSessionContext.authentication_or_reauthentication_context?(session)).to eq true
    end

    it 'returns false when context is confirmation context' do
      UserSessionContext.set_confirmation_context!(session)
      expect(UserSessionContext.authentication_or_reauthentication_context?(session)).to eq false
    end
  end

  describe '.confirmation_context?' do
    it 'returns true when context is confirmation context' do
      UserSessionContext.set_confirmation_context!(session)
      expect(UserSessionContext.confirmation_context?(session)).to eq true
    end

    it 'returns false when context is default or reauth context' do
      UserSessionContext.set_authentication_context!(session)

      expect(UserSessionContext.confirmation_context?(session)).to eq false

      UserSessionContext.set_reauthentication_context!(session)
      expect(UserSessionContext.confirmation_context?(session)).to eq false
    end
  end
end
