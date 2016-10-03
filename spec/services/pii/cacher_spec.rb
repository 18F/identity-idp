require 'rails_helper'

describe Pii::Cacher do
  let(:password) { 'sekrit' }
  let(:user) { create(:user, password: password) }
  let(:profile) { build(:profile, :active, :verified, user: user, ssn: '1234') }
  let(:diff_user) { create(:user, password: password) }
  let(:diff_profile) { build(:profile, :active, :verified, user: diff_user, ssn: '5678') }
  let(:user_session) { {} }

  subject { described_class.new(user, user_session) }

  describe '#save' do
    before do
      profile.encrypt_pii(password)
      profile.save!
    end

    it 'writes re-encrypted PII to user_session' do
      server_encrypted_pii = subject.save(password)

      expect(server_encrypted_pii).to be_a String
      expect(server_encrypted_pii).to_not match '1234'
      expect(user_session[:encrypted_pii]).to eq server_encrypted_pii
    end

    it 'allows specific profile to be re-encrypted' do
      diff_profile.encrypt_pii(password)
      diff_profile.save!
      server_encrypted_pii = subject.save(password, diff_profile)

      expect(server_encrypted_pii).to be_a String
      expect(server_encrypted_pii).to_not match '1234'
      expect(server_encrypted_pii).to_not match '5678'
      expect(user_session[:encrypted_pii]).to eq server_encrypted_pii
    end
  end

  describe '#fetch' do
    before do
      profile.encrypt_pii(password)
      profile.save!
    end

    it 'fetches decrypted PII from user_session' do
      subject.save(password)
      decrypted_pii = subject.fetch

      expect(decrypted_pii).to be_a Pii::Attributes
      expect(decrypted_pii.ssn).to eq '1234'
    end

    it 'allows specific profile to be decrypted' do
      diff_profile.encrypt_pii(password)
      diff_profile.save!
      subject.save(password, diff_profile)
      decrypted_pii = subject.fetch

      expect(decrypted_pii).to be_a Pii::Attributes
      expect(decrypted_pii.ssn).to_not eq '1234'
      expect(decrypted_pii.ssn).to eq '5678'
    end
  end
end
