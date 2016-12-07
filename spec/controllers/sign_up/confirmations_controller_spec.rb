require 'rails_helper'

describe SignUp::ConfirmationsController, devise: true do
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
