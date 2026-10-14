require 'rails_helper'

RSpec.describe SiteKeyRoot do
  describe 'validations' do
    it 'requires a wrapped root' do
      expect(build(:site_key_root, encrypted_root: nil)).not_to be_valid
    end
  end

  describe '#forget_password!' do
    let(:user) { create(:user) }
    let!(:record) { create(:site_key_root, user:) }

    it 'deletes the root' do
      expect { record.forget_password! }.to change { SiteKeyRoot.count }.by(-1)
    end

    it 'clears the user association' do
      user.site_key_root
      record.forget_password!

      expect(user.site_key_root).to be_nil
    end
  end
end
