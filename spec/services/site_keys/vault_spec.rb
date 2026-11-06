require 'rails_helper'

RSpec.describe SiteKeys::Vault do
  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:password) { user.password }
  let(:analytics) { FakeAnalytics.new }

  subject(:vault) { described_class.new(user:, user_session:, analytics:) }

  def fresh_vault
    described_class.new(user: User.find(user.id), user_session: {})
  end

  def rewrap(vault, new_password)
    vault.store_rewrapped!(
      vault.wrap_cached_key(new_password), expected_fingerprint: vault.stored_fingerprint
    )
  end

  describe '#unlock' do
    context 'when the user has no site key' do
      it 'does not create one unless asked to' do
        expect(vault.unlock(password)).to be_nil
        expect(user.reload.site_key).to be_nil
      end

      it 'creates and caches a key pair when asked to' do
        private_key = vault.unlock(password, create: true)

        expect(private_key.bytesize).to eq(32)
        expect(vault.unlocked?).to eq(true)
        expect(analytics).to have_logged_event(:site_key_created)
      end

      it 'stores the public key of the pair' do
        private_key = vault.unlock(password, create: true)

        expect(JSON.parse(user.reload.site_key.public_key))
          .to eq(SiteKeys::KeyPair.from_private_bytes(private_key).public_jwk)
      end

      it 'does not keep the plaintext key in the session' do
        private_key = vault.unlock(password, create: true)

        expect(user_session.values.join).not_to include(Base64.strict_encode64(private_key))
      end
    end

    context 'when the user has a site key' do
      let!(:created) { create_site_key(user) }

      it 'returns the same private key in a new session' do
        expect(vault.unlock(password)).to eq(created.private_key)
      end

      it 'raises a mismatch error for the wrong password' do
        expect { vault.unlock('wrong password!!') }.to raise_error(SiteKeys::MismatchError)
      end

      it 'does not create a second key' do
        expect(vault.unlock(password, create: true)).to eq(created.private_key)
        expect(SiteKey.where(user:).count).to eq(1)
      end
    end
  end

  describe '#replace!' do
    let!(:created) { create_site_key(user, password: 'some other password') }

    it 'drops the stale wrap and makes a new pair for a listed client' do
      private_key = vault.replace!(password, create: true)

      expect(private_key).not_to eq(created.private_key)
      expect(SiteKey.where(user:).count).to eq(1)
      expect(user.reload.site_key.public_key).not_to eq(created.record.public_key)
      expect(vault.unlocked?).to eq(true)
    end

    it 'drops the stale wrap and makes nothing for another client' do
      expect(vault.replace!(password, create: false)).to be_nil
      expect(SiteKey.where(user:).count).to eq(0)
    end

    it 'opens a key another session rewrapped since instead of replacing it' do
      other = fresh_vault
      other.unlock('some other password')
      rewrap(other, password)

      expect(vault.replace!(password, create: true)).to eq(created.private_key)
      expect(user.reload.site_key.public_key).to eq(created.record.public_key)
    end

    it 'does nothing when another session deleted the key' do
      SiteKey.where(user:).delete_all

      expect(vault.replace!(password, create: false)).to be_nil
      expect(SiteKey.where(user:).count).to eq(0)
    end
  end

  describe '#wrap_cached_key and #store_rewrapped!' do
    let!(:created) { create_site_key(user) }

    it 'rewraps the unlocked key under a new password' do
      vault.unlock(password)
      rewrap(vault, 'a brand new password')

      expect(fresh_vault.unlock('a brand new password')).to eq(created.private_key)
    end

    it 'returns nil while the key is locked' do
      expect(vault.wrap_cached_key('a brand new password')).to be_nil
    end

    it 'leaves a key another session rewrapped since alone' do
      expected_fingerprint = vault.stored_fingerprint
      vault.unlock(password)
      other = fresh_vault
      other.unlock(password)
      rewrap(other, 'other session password')

      vault.store_rewrapped!(vault.wrap_cached_key('a brand new password'), expected_fingerprint:)

      expect(fresh_vault.unlock('other session password')).to eq(created.private_key)
    end

    it 'does nothing when another session deleted the key' do
      vault.unlock(password)
      wrap = vault.wrap_cached_key('a brand new password')
      SiteKey.where(user:).delete_all

      expect { vault.store_rewrapped!(wrap, expected_fingerprint: vault.stored_fingerprint) }
        .not_to raise_error
      expect { vault.store_rewrapped!(nil, expected_fingerprint: nil) }.not_to raise_error
    end
  end

  describe '#unlocked?' do
    before { create_site_key(user) }

    it 'is false once another session changes the stored wrap' do
      vault.unlock(password)
      other = fresh_vault
      other.unlock(password)
      rewrap(other, 'a brand new password')
      user.reload

      expect(vault.unlocked?).to eq(false)
    end
  end

  describe '#needs_password?' do
    it 'is true while the key is locked' do
      create_site_key(user)

      expect(vault.needs_password?).to eq(true)
    end

    it 'is false after a transient failure' do
      create_site_key(user)
      vault.mark_unavailable

      expect(vault.needs_password?).to eq(false)
    end

    it 'is false for a user without a key' do
      expect(vault.needs_password?).to eq(false)
    end
  end

  describe '#private_key' do
    let!(:created) { create_site_key(user) }

    it 'returns the private scalar while the key is unlocked' do
      vault.unlock(password)

      expect(vault.private_key).to eq(created.private_key)
    end

    it 'is nil in a session that has not entered the password' do
      expect(vault.private_key).to be_nil
    end
  end
end
