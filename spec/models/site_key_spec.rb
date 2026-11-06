require 'rails_helper'

RSpec.describe SiteKey do
  describe 'validations' do
    it 'requires a public key' do
      expect(build(:site_key, public_key: nil)).not_to be_valid
    end

    it 'allows a missing password wrap' do
      expect(build(:site_key, encrypted_private_key: nil)).to be_valid
    end
  end

  describe '#forget_password!' do
    let(:user) { create(:user) }
    let!(:record) { create(:site_key, user:) }

    it 'deletes the key' do
      expect { record.forget_password! }.to change { SiteKey.count }.by(-1)
    end

    it 'clears the user association' do
      user.site_key
      record.forget_password!

      expect(user.site_key).to be_nil
    end
  end
end
