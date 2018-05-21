require 'rails_helper'

describe ActiveProfileEncryptor do
  describe '#call' do
    it 'encrypts the profile' do
      decrypted_pii = { ssn: '1234' }.to_json
      user_session = { decrypted_pii: decrypted_pii }
      profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
      user = profile.user
      password = user.password
      current_pii = Pii::Attributes.new_from_json(decrypted_pii)

      allow(user).to receive(:active_profile).and_return(profile)
      allow(profile).to receive(:encrypt_pii)
      allow(profile).to receive(:save!)
      allow(Pii::Attributes).to receive(:new_from_json).with(decrypted_pii).
        and_return(current_pii)

      ActiveProfileEncryptor.new(user, user_session, password).call

      expect(profile).to have_received(:encrypt_pii).with(current_pii, password)
      expect(profile).to have_received(:save!)
    end
  end
end
