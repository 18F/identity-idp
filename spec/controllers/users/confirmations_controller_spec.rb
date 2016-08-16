require 'rails_helper'

describe Users::ConfirmationsController, devise: true do
  describe 'Invalid email confirmation tokens' do
    it 'tracks nil email confirmation token' do
      stub_analytics

      expect(@analytics).to receive(:track_anonymous_event).
        with('Invalid Email Confirmation Token', 'nil')

      get :show, confirmation_token: nil
    end

    it 'tracks blank email confirmation token' do
      stub_analytics

      expect(@analytics).to receive(:track_anonymous_event).
        with('Invalid Email Confirmation Token', '')

      get :show, confirmation_token: ''
    end

    it 'tracks confirmation token as a single-quoted empty string' do
      stub_analytics

      expect(@analytics).to receive(:track_anonymous_event).
        with('Invalid Email Confirmation Token', "''")

      get :show, confirmation_token: "''"
    end

    it 'tracks confirmation token as a double-quoted empty string' do
      stub_analytics

      expect(@analytics).to receive(:track_anonymous_event).
        with('Invalid Email Confirmation Token', '""')

      get :show, confirmation_token: '""'
    end

    it 'tracks already confirmed token' do
      user = create(:user, confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).with('GET request for confirmations#show')
      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: User Already Confirmed', user)

      get :show, confirmation_token: 'foo'
    end

    it 'tracks expired token' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo', confirmation_sent_at: Time.current - 2.days)

      stub_analytics

      expect(@analytics).to receive(:track_event).with('GET request for confirmations#show')
      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: token expired', user)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).with('GET request for confirmations#show')
      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: valid token', user)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'initial password creation' do
    it 'tracks a valid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Password Created and User Confirmed', user)

      patch :confirm, password_form: { password: 'NewVal!dPassw0rd' }, confirmation_token: 'foo'
    end

    it 'tracks an invalid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Password Creation: invalid', user)

      patch :confirm, password_form: { password: 'NewVal' }, confirmation_token: 'foo'
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

      expect(@analytics).to receive(:track_event).with('GET request for confirmations#show')
      expect(@analytics).to receive(:track_event).
        with('Email changed and confirmed', user)

      get :show, confirmation_token: 'foo'
    end
  end
end
