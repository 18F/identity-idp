require 'rails_helper'

RSpec.describe SiteKeyRoot do
  describe 'validations' do
    it 'requires at least one wrap' do
      expect(build(:site_key_root, encrypted_root: nil)).not_to be_valid
    end
  end

  describe '#recoverable?' do
    it 'is false for a recovery code that was never acknowledged' do
      record = build(:site_key_root, encrypted_root_recovery_code: 'wrap')

      expect(record.recoverable?).to eq(false)
    end

    it 'is true for an acknowledged recovery code' do
      record = build(
        :site_key_root,
        encrypted_root_recovery_code: 'wrap',
        recovery_code_acknowledged_at: Time.zone.now,
      )

      expect(record.recoverable?).to eq(true)
    end
  end

  describe '#forget_password!' do
    let(:user) { create(:user) }

    context 'when the root is recoverable' do
      let!(:record) do
        create(
          :site_key_root,
          user:,
          encrypted_root_recovery_code: 'wrap',
          recovery_code_acknowledged_at: Time.zone.now,
        )
      end

      it 'drops only the password wrap' do
        record.forget_password!

        expect(record.reload).to have_attributes(
          encrypted_root: nil,
          encrypted_root_recovery_code: 'wrap',
        )
      end
    end

    context 'when nothing else can open the root' do
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
end
