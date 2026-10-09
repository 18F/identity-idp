require 'rails_helper'

RSpec.describe SiteKeyConcern do
  let(:test_controller) do
    Class.new do
      include SiteKeyConcern

      attr_accessor :current_user, :user_session, :analytics, :current_sp

      def initialize(current_user:, user_session:, analytics:, current_sp:)
        @current_user = current_user
        @user_session = user_session
        @analytics = analytics
        @current_sp = current_sp
      end
    end
  end

  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:analytics) { FakeAnalytics.new }
  let(:service_provider) { create(:service_provider, site_key_allowed:) }
  let(:site_key_allowed) { true }
  let(:vault) { SiteKeys::Vault.new(user:, user_session:) }

  subject(:controller) do
    test_controller.new(current_user: user, user_session:, analytics:, current_sp: service_provider)
  end

  before do
    allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
  end

  describe '#site_key_root_wanted?' do
    it 'is true for an SP that uses site keys' do
      expect(controller.site_key_root_wanted?).to eq(true)
    end

    context 'for an SP that does not use site keys' do
      let(:site_key_allowed) { false }

      it 'is false' do
        expect(controller.site_key_root_wanted?).to eq(false)
      end
    end
  end

  describe '#unlock_site_key_root' do
    it 'creates and unlocks a root' do
      controller.unlock_site_key_root(user.password)

      expect(vault.unlocked?).to eq(true)
      expect(analytics).to have_logged_event(:site_key_root_created, replaced: false)
    end

    it 'clears an earlier transient failure' do
      vault.mark_unavailable

      controller.unlock_site_key_root(user.password)

      expect(vault.unavailable?).to eq(false)
    end

    context 'when the password wrap is dead but the root is recoverable' do
      before { create_site_key_root(user, password: 'some other password') }

      it 'drops the password wrap so the root can be recovered' do
        controller.unlock_site_key_root(user.password)

        expect(user.reload.site_key_root.encrypted_root).to be_nil
        expect(analytics).to have_logged_event(
          :site_key_root_unlock_failed, error: kind_of(String), root_replaced: false
        )
      end
    end

    context 'when another session re-wrapped the root during the failed unlock' do
      before do
        create_site_key_root(user, password: 'some other password')
        allow(User).to receive(:find).and_wrap_original do |original, *args|
          other = SiteKeys::Vault.new(user: User.find_by(id: user.id), user_session: {})
          other.unlock('some other password')
          other.store_root!(other.wrap_cached_root(user.password))
          original.call(*args)
        end
      end

      it 'keeps the new password wrap' do
        controller.unlock_site_key_root(user.password)

        expect(user.reload.site_key_root.encrypted_root).to be_present
      end
    end

    context 'when the password wrap is dead and nothing else can open the root' do
      before do
        create_site_key_root(user, password: 'some other password', acknowledge: false)
      end

      it 'replaces the root' do
        controller.unlock_site_key_root(user.password)

        expect(vault.unlocked?).to eq(true)
        expect(analytics).to have_logged_event(
          :site_key_root_unlock_failed, error: kind_of(String), root_replaced: true
        )
      end
    end

    context 'when replacing the dead root fails' do
      before do
        create_site_key_root(user, password: 'some other password', acknowledge: false)
        allow(controller.site_key_vault).to receive(:replace!)
          .and_raise(Encryption::EncryptionError, 'kms down')
      end

      it 'marks the root unavailable instead of failing sign-in' do
        controller.unlock_site_key_root(user.password)

        expect(vault.unavailable?).to eq(true)
      end
    end

    context 'when the password changed concurrently' do
      before do
        create_site_key_root(user, password: 'some other password')
        User.find(user.id).update!(password: 'some other password')
      end

      it 'keeps the root and marks it unavailable' do
        encrypted_root = user.site_key_root.encrypted_root

        controller.unlock_site_key_root(user.password)

        expect(user.reload.site_key_root.encrypted_root).to eq(encrypted_root)
        expect(vault.unavailable?).to eq(true)
      end
    end

    context 'when the root cannot be decrypted for another reason' do
      before do
        create_site_key_root(user)
        user.site_key_root.update!(encrypted_root: 'not json')
      end

      it 'keeps the root and marks it unavailable' do
        controller.unlock_site_key_root(user.password)

        expect(user.reload.site_key_root.encrypted_root).to eq('not json')
        expect(vault.unavailable?).to eq(true)
        expect(analytics).to have_logged_event(
          :site_key_root_unlock_failed, error: kind_of(String), root_replaced: false
        )
      end
    end
  end
end
