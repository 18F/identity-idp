require 'rails_helper'

describe Pii::ReEncryptor do
  describe '#perform' do
    it 're-encrypts PII using new code' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      generator = RecoveryCodeGenerator.new(user)
      allow(RecoveryCodeGenerator).to receive(:new).and_return(generator)

      user.unlock_user_access_key(user.password)
      user_session = {}
      cacher = Pii::Cacher.new(user, user_session)
      cacher.save(user.user_access_key, profile)
      allow(Pii::Cacher).to receive(:new).and_return(cacher)

      expect(user.active_profile).to receive(:save!).and_call_original

      Pii::ReEncryptor.new(user, user_session).perform
    end
  end
end
