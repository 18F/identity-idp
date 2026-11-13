require 'rails_helper'

RSpec.describe SiteKey do
  describe 'validations' do
    it 'requires a public key' do
      expect(build(:site_key, public_key: nil)).not_to be_valid
    end

    it 'requires at least one wrap' do
      expect(build(:site_key, encrypted_private_key: nil)).not_to be_valid
    end

    it 'allows a missing password wrap when a recovery wrap is present' do
      key = build(:site_key, encrypted_private_key: nil, encrypted_private_key_recovery_code: 'r')
      expect(key).to be_valid
    end
  end

  describe '#recoverable?' do
    it 'is true only with an acknowledged recovery wrap' do
      expect(
        build(
          :site_key, encrypted_private_key_recovery_code: 'r',
                     recovery_code_acknowledged_at: Time.zone.now
        ),
      )
        .to be_recoverable
      expect(
        build(
          :site_key, encrypted_private_key_recovery_code: 'r',
                     recovery_code_acknowledged_at: nil
        ),
      )
        .not_to be_recoverable
      expect(
        build(
          :site_key, encrypted_private_key_recovery_code: nil,
                     recovery_code_acknowledged_at: Time.zone.now
        ),
      )
        .not_to be_recoverable
    end
  end

  describe '#forget_password!' do
    let(:user) { create(:user) }

    context 'when nothing else can open the key' do
      let!(:record) { create(:site_key, user:) }

      it 'deletes the key and clears the association' do
        expect { record.forget_password! }.to change { SiteKey.count }.by(-1)
        expect(user.site_key).to be_nil
      end
    end

    context 'when an acknowledged recovery code can still open the key' do
      let!(:record) do
        create(
          :site_key, user:, encrypted_private_key_recovery_code: 'r',
                     recovery_code_acknowledged_at: Time.zone.now
        )
      end

      it 'drops only the password wrap' do
        expect { record.forget_password! }.not_to change { SiteKey.count }
        expect(record.reload.encrypted_private_key).to be_nil
        expect(record.encrypted_private_key_recovery_code).to eq('r')
      end
    end
  end
end
