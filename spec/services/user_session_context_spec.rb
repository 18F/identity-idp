require 'rails_helper'

describe UserSessionContext do
  let(:confirmation) { { context: 'confirmation' } }

  describe '.authentication_context?' do
    it 'returns true when context is default context' do
      expect(
        UserSessionContext.authentication_context?(UserSessionContext::AUTHENTICATION_CONTEXT),
      ).to eq true
    end

    it 'returns false when context is not default context' do
      expect(
        UserSessionContext.authentication_context?(
          UserSessionContext::CONFIRMATION_CONTEXT,
        ),
      ).to eq false

      expect(
        UserSessionContext.authentication_context?(
          UserSessionContext::REAUTHENTICATION_CONTEXT,
        ),
      ).to eq false
    end
  end

  describe '.reauthentication_context?' do
    it 'returns true when context is reauthn context' do
      expect(
        UserSessionContext.reauthentication_context?(UserSessionContext::REAUTHENTICATION_CONTEXT),
      ).to eq true
    end

    it 'returns false when context is default context' do
      expect(
        UserSessionContext.reauthentication_context?(UserSessionContext::AUTHENTICATION_CONTEXT),
      ).to eq false
    end
  end

  describe '.authentication_or_reauthentication_context?' do
    it 'returns true when context is default or reauth context' do
      expect(
        UserSessionContext.authentication_or_reauthentication_context?(
          UserSessionContext::AUTHENTICATION_CONTEXT,
        ),
      ).to eq true

      expect(
        UserSessionContext.authentication_or_reauthentication_context?(
          UserSessionContext::REAUTHENTICATION_CONTEXT,
        ),
      ).to eq true
    end

    it 'returns false when context is confirmation context' do
      expect(
        UserSessionContext.authentication_context?(
          UserSessionContext::CONFIRMATION_CONTEXT,
        ),
      ).to eq false
    end
  end

  describe '.confirmation_context?' do
    it 'returns true when context is confirmation context' do
      expect(
        UserSessionContext.confirmation_context?(UserSessionContext::CONFIRMATION_CONTEXT),
      ).to eq true
    end

    it 'returns false when context is default or reauth context' do
      expect(
        UserSessionContext.confirmation_context?(UserSessionContext::AUTHENTICATION_CONTEXT),
      ).to eq false

      expect(
        UserSessionContext.confirmation_context?(UserSessionContext::REAUTHENTICATION_CONTEXT),
      ).to eq false
    end
  end
end
