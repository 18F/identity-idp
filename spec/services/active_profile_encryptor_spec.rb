require 'rails_helper'

describe ActiveProfileEncryptor do
  describe '#call' do
    it 'encrypts the profile' do
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      password = user.password
      user_session = { }

      cacher = Pii::Cacher.new(user, user_session)
      cacher.save(password, profile)

      current_pii = cacher.fetch

      allow(user).to receive(:active_profile).and_return(profile)
      allow(profile).to receive(:encrypt_pii)
      allow(profile).to receive(:save!)

      ActiveProfileEncryptor.new(user, user_session, password).call

      expect(profile).to have_received(:encrypt_pii).with(current_pii, password)
      expect(profile).to have_received(:save!)
    end
  end
end
