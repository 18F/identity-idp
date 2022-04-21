require 'rails_helper'

RSpec.describe Api::ProfileCreationForm do
  let(:password) { 'salty pickles' }
  let(:entered_password) { password }
  let(:user) { create(:user, password: password) }
  let(:uuid) { user.uuid }
  let(:pii) do
    { first_name: 'Ada', last_name: 'Lovelace', ssn: '900-90-0900' }
  end
  let(:key) { OpenSSL::PKey::RSA.new 2048 }
  let(:pub) { key.public_key }
  let(:bundle) do
    JWT.encode(pii, key, 'RS256', sub: uuid.to_s)
  end

  subject do
    Api::ProfileCreationForm.new(
      user_password: entered_password,
      user_bundle: bundle,
      user_session: {},
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_private_key).
                                     and_return(Base64.strict_encode64(key.to_s))
    allow(IdentityConfig.store).to receive(:idv_public_key).
                                     and_return(Base64.strict_encode64(pub.to_s))
  end

  describe '#submit' do
    context 'with the correct password' do
      it 'returns a successful response with the personal_key in the extra hash' do
        response = subject.submit

        expect(response.success?).to be true
        expect(response.extra[:personal_key]).to be_present
      end

      it 'creates and saves the user profile' do
        expect(user.profiles.count).to eq 0

        subject.submit

        expect(user.profiles.count).to eq 1
      end

      it 'saves the user pii encrypted with their password in the profile' do
        subject.submit
        profile = user.profiles.first
        decrypted_pii = profile.decrypt_pii(password)

        expect(decrypted_pii[:first_name]).to eq 'Ada'
      end

      it 'saves the user pii encrypted with their personal_key in the profile' do
        response = subject.submit
        profile = user.profiles.first
        personal_key = PersonalKeyGenerator.new(user).normalize(response.extra[:personal_key])
        decrypted_recovery_pii = profile.recover_pii(personal_key)

        expect(decrypted_recovery_pii[:first_name]).to eq 'Ada'
      end
    end

    context 'with an incorrect password' do
      let(:entered_password) { 'wild guess' }

      it 'returns an unsuccessful response with an error about the password' do
        response = subject.submit

        expect(response.success?).to be false
        expect(response.extra[:personal_key]).to be_nil
        expect(response.errors[:password]).to eq ['invalid password']
      end
    end

    context 'with a non-existent user' do
      let(:uuid) { SecureRandom.uuid }

      it 'returns an unsuccessful response with an error about the user' do
        response = subject.submit

        expect(response.success?).to be false
        expect(response.extra[:personal_key]).to be_nil
        expect(response.errors[:user]).to eq ['user not found']
      end
    end

    context 'with an expired JWT' do
      let(:bundle) { JWT.encode(pii.merge(exp: 1.day.ago.to_i), key, 'RS256', sub: uuid.to_s) }

      it 'returns an unsuccessful response with an error about the jwt' do
        response = subject.submit

        expect(response.success?).to be false
        expect(response.extra[:personal_key]).to be_nil
        expect(response.errors[:jwt]).to eq ['decode error: Signature has expired']
      end
    end
  end

  describe '#valid?' do
    context 'with the correct password' do
      it 'is a valid form' do
        expect(subject.valid?).to be true
      end
    end

    context 'with an incorrect password' do
      let(:entered_password) { 'wild guess' }

      it 'is an invalid form' do
        expect(subject.valid?).to be false
      end
    end

    context 'with a non-existent user' do
      let(:uuid) { SecureRandom.uuid }

      it 'is an invalid form' do
        expect(subject.valid?).to be false
      end
    end

    context 'with an expired JWT' do
      let(:bundle) { JWT.encode(pii.merge(exp: 1.day.ago.to_i), key, 'RS256', sub: uuid.to_s) }

      it 'is an invalid form' do
        expect(subject.valid?).to be false
      end
    end
  end
end
