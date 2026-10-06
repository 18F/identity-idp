require 'rails_helper'

RSpec.describe Accounts::PersonalKeysController do
  describe 'before_actions' do
    it 'require recent reauthn' do
      expect(subject).to have_actions(
        :before,
        :confirm_recently_authenticated_2fa,
        :prompt_for_password_if_pii_locked,
      )
    end
  end

  describe '#new' do
    it 'tracks an event for viewing profile personal key' do
      stub_sign_in(create(:user, :with_phone))
      stub_analytics

      get :new

      expect(@analytics).to have_logged_event('Profile: Visited new personal key')
    end
  end

  describe '#create' do
    it 'generates a new personal key, tracks an analytics event, and redirects' do
      stub_sign_in(create(:user, :with_phone))
      stub_analytics

      generator = instance_double(PersonalKeyGenerator)
      allow(PersonalKeyGenerator).to receive(:new)
        .with(subject.current_user).and_return(generator)

      expect(generator).to receive(:generate!)

      post :create

      expect(@analytics).to have_logged_event('Profile: Created new personal key')
      expect(@analytics).to have_logged_event(
        'Profile: Created new personal key notifications',
        hash_including(emails: 1, sms_message_ids: ['fake-message-id']),
      )
      expect(response).to redirect_to manage_personal_key_path
      expect(flash[:info]).to eq(t('account.personal_key.old_key_will_not_work'))
    end

    it 'tracks CSRF errors' do
      stub_sign_in
      stub_analytics
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      post :create

      expect(@analytics).to have_logged_event(
        'Invalid Authenticity Token',
        controller: 'accounts/personal_keys#create',
        user_signed_in: true,
      )
      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    context 'for an identity-verified user with a site key root' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '1234' }) }
      let(:user) { profile.user }

      before do
        allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
        stub_sign_in(user)
        Pii::Cacher.new(user, subject.user_session).save_decrypted_pii({ ssn: '1234' }, profile.id)
      end

      it 'prompts for the password when the root is locked' do
        create_site_key_root(user)

        post :create

        expect(response).to redirect_to capture_password_url
      end

      it 'wraps the root under the new personal key' do
        root = SiteKeys::Vault.new(user:, user_session: subject.user_session)
          .unlock(user.password, create: true)

        post :create

        personal_key = subject.user_session[:personal_key]
        user.reload.site_key_root.forget_password!
        expect(SiteKeys::Vault.new(user: user.reload, user_session: {}).recover(personal_key))
          .to eq(root)
      end
    end

    it 'leaves site keys alone for a user who is not identity-verified' do
      allow(IdentityConfig.store).to receive(:site_key_enabled).and_return(true)
      user = create(:user, :fully_registered)
      create_site_key_root(user)
      stub_sign_in(user)

      post :create

      expect(response).to redirect_to manage_personal_key_path
      expect(user.reload.site_key_root.encrypted_root_personal_key).to be_nil
    end

    it 'prompts for password if PII is not present' do
      user = create(:user, :fully_registered, :with_piv_or_cac)
      create(:profile, :active, :verified, user: user)
      stub_sign_in(user)

      post :create

      expect(response).to redirect_to capture_password_url

      Pii::Cacher.new(user, subject.user_session).save_decrypted_pii(
        { verified_at: Time.zone.now },
        123,
      )

      post :create

      expect(response).to redirect_to manage_personal_key_path
      expect(flash[:info]).to eq(t('account.personal_key.old_key_will_not_work'))
    end
  end
end
