require 'rails_helper'

RSpec.describe Accounts::PersonalKeysController do
  describe 'before_actions' do
    it 'require recent reauthn' do
      expect(subject).to have_actions(
        :before,
        :confirm_recently_authenticated,
        :prompt_for_password_if_pii_locked,
      )
    end
  end

  describe '#new' do
    it 'tracks an event for viewing profile personal key' do
      stub_sign_in(create(:user, :with_phone))
      stub_analytics

      expect(@analytics).to receive(:track_event).with('Profile: Visited new personal key')

      get :new
    end
  end

  describe '#create' do
    it 'generates a new personal key, tracks an analytics event, and redirects' do
      stub_sign_in(create(:user, :with_phone))
      stub_analytics

      generator = instance_double(PersonalKeyGenerator)
      allow(PersonalKeyGenerator).to receive(:new).
        with(subject.current_user).and_return(generator)

      expect(generator).to receive(:create)
      expect(@analytics).to receive(:track_event).with('Profile: Created new personal key')
      expect(@analytics).to receive(:track_event).with(
        'Profile: Created new personal key notifications',
        hash_including(emails: 1, sms_message_ids: ['fake-message-id']),
      )

      post :create

      expect(response).to redirect_to manage_personal_key_path
      expect(flash[:info]).to eq(t('account.personal_key.old_key_will_not_work'))
    end

    it 'tracks CSRF errors' do
      stub_sign_in
      stub_analytics
      analytics_hash = {
        controller: 'accounts/personal_keys#create',
        user_signed_in: true,
      }
      allow(controller).to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)

      expect(@analytics).to receive(:track_event).
        with('Invalid Authenticity Token', analytics_hash)

      post :create

      expect(response).to redirect_to new_user_session_url
      expect(flash[:error]).to eq t('errors.general')
    end

    it 'prompts for password if PII is not present' do
      user = create(:user, :signed_up, :with_piv_or_cac)
      create(:profile, :active, :verified, user: user)
      stub_sign_in(user)

      post :create

      expect(response).to redirect_to capture_password_url

      subject.user_session[:decrypted_pii] = { verified_at: Time.zone.now }.to_json

      post :create

      expect(response).to redirect_to manage_personal_key_path
      expect(flash[:info]).to eq(t('account.personal_key.old_key_will_not_work'))
    end
  end
end
