require 'rails_helper'

describe Users::ConfirmationsController, devise: true do
  describe 'Invalid email confirmation tokens' do
    before do
      stub_analytics
    end

    it 'tracks nil email confirmation token' do
      analytics_hash = {
        success: false,
        error: 'Confirmation token Please fill in this field.',
        user_id: nil,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: nil
    end

    it 'tracks blank email confirmation token' do
      analytics_hash = {
        success: false,
        error: 'Confirmation token Please fill in this field.',
        user_id: nil,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: ''
    end

    it 'tracks confirmation token as a single-quoted empty string' do
      analytics_hash = {
        success: false,
        error: 'Confirmation token is invalid',
        user_id: nil,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: "''"
    end

    it 'tracks confirmation token as a double-quoted empty string' do
      analytics_hash = {
        success: false,
        error: 'Confirmation token is invalid',
        user_id: nil,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: '""'
    end

    it 'tracks already confirmed token' do
      user = create(:user, confirmation_token: 'foo')

      analytics_hash = {
        success: false,
        error: 'Email was already confirmed, please try signing in',
        user_id: user.uuid,
        existing_user: true
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: 'foo'
    end

    it 'tracks expired token' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo', confirmation_sent_at: Time.current - 2.days)

      analytics_hash = {
        success: false,
        error: 'Confirmation token has expired',
        user_id: user.uuid,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      analytics_hash = {
        success: true,
        error: '',
        user_id: user.uuid,
        existing_user: false
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'initial password creation' do
    it 'tracks a valid password event' do
      user = create(:user, :unconfirmed)
      token, = Devise.token_generator.generate(User, :confirmation_token)
      user.update(
        confirmation_token: token, confirmation_sent_at: Time.current
      )

      stub_analytics

      analytics_hash = {
        success: true,
        errors: [],
        user_id: user.uuid
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATION, analytics_hash)

      patch :confirm, password_form: { password: 'NewVal!dPassw0rd' }, confirmation_token: token

      expect(user.reload.valid_password?('NewVal!dPassw0rd')).to eq true
    end

    it 'tracks an invalid password event' do
      user = create(:user, :unconfirmed)
      token, = Devise.token_generator.generate(User, :confirmation_token)
      user.update(
        confirmation_token: token, confirmation_sent_at: Time.current
      )

      stub_analytics

      analytics_hash = {
        success: false,
        errors: ['is too short (minimum is 8 characters)'],
        user_id: user.uuid
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATION, analytics_hash)

      patch :confirm, password_form: { password: 'NewVal' }, confirmation_token: token
    end

    it 'calls PasswordForm#submit' do
      form = instance_double(PasswordForm)
      allow(PasswordForm).to receive(:new).and_return(form)

      analytics_hash = {
        success: true,
        errors: []
      }

      expect(form).to receive(:submit).with(password: 'password').
        and_return(analytics_hash)

      patch :confirm, password_form: { password: 'password' }, confirmation_token: 'foo'
    end
  end

  describe 'User confirms new email' do
    it 'tracks the event' do
      user = create(:user, :signed_up)
      user.update(
        confirmation_token: 'foo',
        confirmation_sent_at: Time.current,
        unconfirmed_email: 'test@example.com'
      )

      stub_analytics

      analytics_hash = {
        success: true,
        error: '',
        user_id: user.uuid,
        existing_user: true
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION, analytics_hash)

      get :show, confirmation_token: 'foo'
    end
  end
end
