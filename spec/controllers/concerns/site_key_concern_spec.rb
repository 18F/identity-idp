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
  let(:service_provider) { create(:service_provider, pkce: true) }
  let(:listed) { true }
  let(:vault) { SiteKeys::Vault.new(user:, user_session:) }

  subject(:controller) do
    test_controller.new(current_user: user, user_session:, analytics:, current_sp: service_provider)
  end

  before { allow_site_keys_for(service_provider) if listed }

  describe '#site_key_wanted?' do
    it 'is true for a listed client' do
      expect(controller.site_key_wanted?).to eq(true)
    end

    context 'for a client that is not listed' do
      let(:listed) { false }

      it 'is false' do
        expect(controller.site_key_wanted?).to eq(false)
      end
    end
  end

  describe '#unlock_site_key' do
    it 'creates and unlocks a key' do
      controller.unlock_site_key(user.password)

      expect(vault.unlocked?).to eq(true)
      expect(analytics).to have_logged_event(:site_key_created)
    end

    it 'clears an earlier transient failure' do
      vault.mark_unavailable

      controller.unlock_site_key(user.password)

      expect(vault.unavailable?).to eq(false)
    end

    context 'when the password wrap is stale' do
      let!(:created) { create_site_key(user, password: 'some other password') }

      it 'replaces the key once the person is fully authenticated' do
        controller.unlock_site_key(user.password)

        expect(vault.unlocked?).to eq(true)
        expect(user.reload.site_key.public_key).not_to eq(created.record.public_key)
        expect(analytics).to have_logged_event(
          :site_key_unlock_failed, error: kind_of(String), replaced: true
        )
      end

      it 'only marks it unavailable before the second factor' do
        controller.unlock_site_key(user.password, repair: false)

        expect(vault.unavailable?).to eq(true)
        expect(user.reload.site_key.public_key).to eq(created.record.public_key)
      end
    end

    context 'when replacing the stale key fails' do
      before do
        create_site_key(user, password: 'some other password')
        allow(controller.site_key_vault).to receive(:replace!)
          .and_raise(Encryption::EncryptionError, 'kms down')
      end

      it 'marks the key unavailable instead of failing sign-in' do
        controller.unlock_site_key(user.password)

        expect(vault.unavailable?).to eq(true)
      end
    end

    context 'when the password changed concurrently' do
      before do
        create_site_key(user, password: 'some other password')
        User.find(user.id).update!(password: 'some other password')
      end

      it 'keeps the key and marks it unavailable' do
        wrap = user.site_key.encrypted_private_key

        controller.unlock_site_key(user.password)

        expect(user.reload.site_key.encrypted_private_key).to eq(wrap)
        expect(vault.unavailable?).to eq(true)
      end
    end

    context 'when the key cannot be decrypted for another reason' do
      before do
        create_site_key(user)
        user.site_key.update!(encrypted_private_key: 'not json')
      end

      it 'keeps the key and marks it unavailable' do
        controller.unlock_site_key(user.password)

        expect(user.reload.site_key.encrypted_private_key).to eq('not json')
        expect(vault.unavailable?).to eq(true)
        expect(analytics).to have_logged_event(
          :site_key_unlock_failed, error: kind_of(String), replaced: false
        )
      end
    end
  end
end
