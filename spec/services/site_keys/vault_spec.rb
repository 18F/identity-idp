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

      it 'stages a recovery code for display' do
        vault.unlock(password, create: true)

        expect(vault.pending_recovery_code).to match(/\A[0-9A-Z]{4}(-[0-9A-Z]{4}){3}\z/)
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

    context 'when the recovery code was never acknowledged' do
      let!(:created) { create_site_key_root(user, acknowledge: false) }

      it 'mints a fresh code to show' do
        vault.unlock(password)

        expect(vault.pending_recovery_code).to be_present
        expect(vault.pending_recovery_code).not_to eq(created.recovery_code)
      end
    end

    context 'when the root was recovered in this session' do
      let!(:created) { create_site_key_root(user) }

      before do
        user.site_key_root.forget_password!
        vault.recover(created.recovery_code)
      end

      it 'wraps the root under the new password' do
        vault.unlock('a brand new password')

        fresh = described_class.new(user: user.reload, user_session: {})
        expect(fresh.unlock('a brand new password')).to eq(created.root)
      end
    end

    context 'when nothing can open the root any more' do
      before do
        create_site_key_root(user, acknowledge: false)
        user.site_key_root.update_columns(encrypted_root: nil)
      end

      it 'replaces it when creating' do
        expect(vault.unlock(password, create: true)).to be_present
        expect(user.reload.site_key_root.encrypted_root).to be_present
      end

      it 'leaves it alone before the second factor' do
        expect(vault.unlock(password, create: true, repair: false)).to be_nil
        expect(user.reload.site_key_root.encrypted_root).to be_nil
      end

      it 'leaves it alone when another session made it recoverable first' do
        SiteKeyRoot.where(user:).update_all(recovery_code_acknowledged_at: Time.zone.now)

        expect(vault.unlock(password, create: true)).to be_nil
      end
    end
  end

  describe '#replace!' do
    let!(:created) { create_site_key_root(user) }

    it 'drops the old personal key wrap' do
      vault.wrap_personal_key(PersonalKeyGenerator.new(user).generate!, password:)

      vault.replace!(password)

      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
    end

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

  describe '#recover' do
    let!(:created) { create_site_key_root(user) }

    before { user.site_key_root.forget_password! }

    it 'opens the root with the recovery code' do
      expect(vault.recover(created.recovery_code)).to eq(created.root)
      expect(vault.unlocked?).to eq(true)
    end

    it 'returns nil for a wrong code' do
      expect(vault.recover(SiteKeys::RecoveryCode.generate)).to be_nil
      expect(vault.unlocked?).to eq(false)
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

  describe '#wrap_personal_key' do
    let!(:created) { create_site_key_root(user) }
    let(:personal_key) { PersonalKeyGenerator.new(user).generate! }

    it 'lets the personal key recover the root after a password reset' do
      vault.unlock(password)
      vault.wrap_personal_key(personal_key)
      user.site_key_root.forget_password!

      fresh = described_class.new(user: user.reload, user_session: {})
      expect(fresh.recover(personal_key)).to eq(created.root)
    end

    it 'unlocks with the password when the session is locked' do
      vault.wrap_personal_key(personal_key, password:)

      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_present
    end

    it 'drops the previous key wrap while the session is locked and no password is given' do
      vault.wrap_personal_key(personal_key, password:)
      locked = described_class.new(user: user.reload, user_session: {})

      locked.wrap_personal_key(PersonalKeyGenerator.new(user).generate!)

      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
    end

    it 'drops the previous key wrap when regenerating after a password reset' do
      vault.wrap_personal_key(personal_key, password:)
      user.reload.site_key_root.forget_password!
      recoverable = described_class.new(user: user.reload, user_session: {})

      recoverable.wrap_personal_key(PersonalKeyGenerator.new(user).generate!)

      expect(recoverable.recover(personal_key)).to be_nil
      expect(recoverable.recover(created.recovery_code)).to eq(created.root)
    end

    it 'does not abort an enclosing transaction when the write fails' do
      vault.unlock(password)
      allow_any_instance_of(SiteKeyRoot).to receive(:update!)
        .and_raise(ActiveRecord::StatementInvalid)

      ActiveRecord::Base.transaction do
        vault.wrap_personal_key(personal_key)
        expect { User.find(user.id) }.not_to raise_error
      end
    end

    it 'never wraps under a malformed personal key' do
      vault.unlock(password)
      vault.wrap_personal_key('too short')

      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
    end
  end

  describe '#consume_personal_key' do
    let!(:created) { create_site_key_root(user) }
    let(:personal_key) { PersonalKeyGenerator.new(user).generate! }

    before do
      described_class.new(user:, user_session: {}).wrap_personal_key(personal_key, password:)
      user.reload.site_key_root.forget_password!
    end

    it 'opens a post-reset root with the key being retired' do
      vault.consume_personal_key(personal_key)

      expect(vault.site_key(issuer)).to eq(derive_site_key(created.root, issuer))
    end

    it 'drops the personal key wrap' do
      vault.consume_personal_key(personal_key)

      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
    end

    context 'when the personal key wrap cannot be decrypted' do
      before { user.site_key_root.update!(encrypted_root_personal_key: 'not json') }

      it 'still drops the personal key wrap' do
        vault.consume_personal_key(personal_key)

        expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
      end
    end

    context 'when the personal key wrap is the only usable one' do
      before { user.site_key_root.update!(recovery_code_acknowledged_at: nil) }

      it 'keeps the personal key wrap so the root stays openable' do
        vault.consume_personal_key(personal_key)

        expect(user.reload.site_key_root.encrypted_root_personal_key).to be_present
        expect(described_class.new(user:, user_session: {}).recover(personal_key))
          .to eq(created.root)
      end
    end
  end

  describe '#acknowledge_recovery_code' do
    before { vault.unlock(password, create: true) }

    it 'records the acknowledgement' do
      expect(vault.acknowledge_recovery_code).to eq(true)
      expect(user.site_key_root.recovery_code_acknowledged_at).to be_present
      expect(vault.pending_recovery_code).to be_nil
    end

    context 'when no code is pending in this session' do
      before { vault.acknowledge_recovery_code }

      it 'refuses the acknowledgement' do
        user.site_key_root.update!(recovery_code_acknowledged_at: nil)

        expect(vault.acknowledge_recovery_code).to eq(false)
      end
    end

    context 'when another session has replaced the code' do
      before do
        described_class.new(user: User.find(user.id), user_session: {}).unlock(password)
        user.reload
      end

      it 'refuses the acknowledgement' do
        expect(vault.acknowledge_recovery_code).to eq(false)
        expect(user.site_key_root.recovery_code_acknowledged_at).to be_nil
      end
    end
  end

  describe '#regenerate_recovery_code' do
    let!(:created) { create_site_key_root(user) }

    it 'invalidates the previous code' do
      vault.unlock(password)
      new_code = vault.regenerate_recovery_code
      vault.acknowledge_recovery_code
      user.site_key_root.forget_password!

      fresh = described_class.new(user: user.reload, user_session: {})
      expect(fresh.recover(created.recovery_code)).to be_nil
      expect(fresh.recover(new_code)).to eq(created.root)
    end

    it 'returns nil while the root is locked' do
      expect(vault.regenerate_recovery_code).to be_nil
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

  describe '#status' do
    it 'needs the password when the root is locked' do
      create_site_key_root(user)

      expect(vault.status).to eq(:needs_password)
    end

    it 'needs acknowledgement when a code is pending' do
      vault.unlock(password, create: true)

      expect(vault.status).to eq(:needs_acknowledgement)
    end

    it 'needs acknowledgement when the stored code was never acknowledged' do
      create_site_key_root(user, acknowledge: false)
      vault.unlock(password, show_recovery_code: false)

      expect(vault.status).to eq(:needs_acknowledgement)
    end

    it 'is ready when unlocked and acknowledged' do
      vault.unlock(password, create: true)
      vault.acknowledge_recovery_code

      expect(vault.status).to eq(:ready)
    end

    it 'needs recovery after a password reset' do
      create_site_key_root(user)
      user.site_key_root.forget_password!

      expect(vault.status).to eq(:needs_recovery)
    end

    it 'is unavailable after a transient failure' do
      create_site_key_root(user)
      vault.mark_unavailable

      expect(vault.status).to eq(:unavailable)
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
