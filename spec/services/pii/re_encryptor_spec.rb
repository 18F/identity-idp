require 'rails_helper'

RSpec.describe Pii::ReEncryptor do
  describe '#perform' do
    it 're-encrypts PII onto the active profile using new code' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })

      user = profile.user

      # make sure it doesn't use this
      create(:profile, :verify_by_mail_pending, user: user, pii: { ssn: '5678' })

      user_session = {}.with_indifferent_access
      cacher = Pii::Cacher.new(user, user_session)
      cacher.save_decrypted_pii({ ssn: '1234' }, profile.id)

      Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      personal_key = user.active_profile.personal_key
      dr_attributes = Profile.find(profile.id).recover_pii(personal_key.gsub(/-/, ' '))

      pii_attributes = Pii::Attributes.new
      pii_attributes[:ssn] = '1234'

      expect(dr_attributes).to eq(pii_attributes)
    end

    it 're-encrypts PII onto the pending profile using new code' do
      profile = create(:profile, :verify_by_mail_pending, pii: { ssn: '5678' })

      user = profile.user

      user_session = {}.with_indifferent_access
      cacher = Pii::Cacher.new(user, user_session)
      cacher.save_decrypted_pii({ ssn: '5678' }, profile.id)

      Pii::ReEncryptor.new(user: user, user_session: user_session).perform
      personal_key = user.pending_profile.personal_key
      dr_attributes = Profile.find(profile.id).recover_pii(personal_key.gsub(/-/, ' '))

      pii_attributes = Pii::Attributes.new
      pii_attributes[:ssn] = '5678'

      expect(dr_attributes).to eq(pii_attributes)
    end
  end
end
