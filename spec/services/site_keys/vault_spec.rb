require 'rails_helper'

RSpec.describe SiteKeys::Vault do
  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:password) { user.password }
  let(:issuer) { 'urn:gov:gsa:openidconnect:test' }
  let(:analytics) { FakeAnalytics.new }

  subject(:vault) { described_class.new(user:, user_session:, analytics:) }

  before do
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
  end

  describe '#unlock' do
    context 'when the user has no root' do
      it 'does not create one unless asked to' do
        expect(vault.unlock(password)).to be_nil
        expect(user.reload.site_key_root).to be_nil
      end

      it 'creates and caches a root when asked to' do
        root = vault.unlock(password, create: true)

        expect(root.bytesize).to eq(32)
        expect(vault.unlocked?).to eq(true)
        expect(analytics).to have_logged_event(:site_key_root_created, replaced: false)
      end

      it 'does not keep the plaintext root in the session' do
        root = vault.unlock(password, create: true)

        expect(user_session.values.join).not_to include(Base64.strict_encode64(root))
      end
    end

    context 'when site keys are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(false)
      end

      it 'does nothing' do
        expect(vault.unlock(password, create: true)).to be_nil
        expect(user.reload.site_key_root).to be_nil
      end
    end

    context 'when the user has a root' do
      let!(:created) { create_site_key_root(user) }

      it 'returns the same root in a new session' do
        expect(vault.unlock(password)).to eq(created.root)
      end

      it 'raises a mismatch error for the wrong password' do
        expect { vault.unlock('wrong password!!') }.to raise_error(SiteKeys::RootMismatchError)
      end

      it 'does not create a second root' do
        expect(vault.unlock(password, create: true)).to eq(created.root)
        expect(SiteKeyRoot.where(user:).count).to eq(1)
      end
    end
  end

  describe '#replace!' do
    let!(:created) { create_site_key_root(user) }

    it 'starts a new root' do
      expect(vault.replace!(password)).not_to eq(created.root)
      expect(analytics).to have_logged_event(:site_key_root_created, replaced: true)
    end

    it 'leaves a root another session changed since alone' do
      expected_fingerprint = vault.send(:fingerprint)
      other = described_class.new(user: User.find(user.id), user_session: {})
      other.unlock(password)
      other.store_root!(other.wrap_cached_root('a brand new password'))

      expect(vault.replace!(password, expected_fingerprint:)).to be_nil
      expect(
        described_class.new(
          user: user.reload,
          user_session: {},
        ).unlock('a brand new password'),
      )
        .to eq(created.root)
    end

    it 'does nothing when another session deleted the root' do
      SiteKeyRoot.where(user:).delete_all

      expect(vault.replace!(password)).to be_nil
      expect(SiteKeyRoot.where(user:).count).to eq(0)
    end
  end

  describe '#store_root_or_forget!' do
    let!(:created) { create_site_key_root(user) }

    it 'does nothing when another session deleted the root' do
      SiteKeyRoot.where(user:).delete_all

      expect { vault.store_root_or_forget!(nil, expected_fingerprint: nil) }.not_to raise_error
    end
  end

  describe '#wrap_cached_root' do
    let!(:created) { create_site_key_root(user) }

    it 'wraps the unlocked root under a new password' do
      vault.unlock(password)
      vault.store_root!(vault.wrap_cached_root('a brand new password'))

      fresh = described_class.new(user: user.reload, user_session: {})
      expect(fresh.unlock('a brand new password')).to eq(created.root)
    end

    it 'returns nil while the root is locked' do
      expect(vault.wrap_cached_root('a brand new password')).to be_nil
    end
  end

  describe '#unlocked?' do
    before { create_site_key_root(user) }

    it 'is false once another session changes the stored root' do
      vault.unlock(password)
      other = described_class.new(user: User.find(user.id), user_session: {})
      other.unlock(password)
      other.store_root!(other.wrap_cached_root('a brand new password'))
      user.reload

      expect(vault.unlocked?).to eq(false)
    end
  end

  describe '#needs_password?' do
    before { create_site_key_root(user) }

    it 'is true while the root is locked' do
      expect(vault.needs_password?).to eq(true)
    end

    it 'is false after a transient failure' do
      vault.mark_unavailable

      expect(vault.needs_password?).to eq(false)
    end
  end

  describe '#site_key' do
    before { vault.unlock(password, create: true) }

    it 'derives a different key per issuer' do
      expect(vault.site_key(issuer)).not_to eq(vault.site_key('urn:other'))
    end

    it 'raises while the root is locked' do
      locked = described_class.new(user: user.reload, user_session: {})

      expect { locked.site_key(issuer) }.to raise_error(SiteKeys::SealError)
    end
  end
end
