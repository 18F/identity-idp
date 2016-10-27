require 'rails_helper'

describe Users::ConfirmationsController, devise: true do
  describe 'Invalid email confirmation tokens' do
    before do
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('GET Request', controller: 'confirmations', action: 'show')
    end

    it 'tracks nil email confirmation token' do
      expect(@analytics).to receive(:track_event).
        with('Invalid Email Confirmation Token', token: 'nil')

      get :show, confirmation_token: nil
    end

    it 'tracks blank email confirmation token' do
      expect(@analytics).to receive(:track_event).
        with('Invalid Email Confirmation Token', token: '')

      get :show, confirmation_token: ''
    end

    it 'tracks confirmation token as a single-quoted empty string' do
      expect(@analytics).to receive(:track_event).
        with('Invalid Email Confirmation Token', token: "''")

      get :show, confirmation_token: "''"
    end

    it 'tracks confirmation token as a double-quoted empty string' do
      expect(@analytics).to receive(:track_event).
        with('Invalid Email Confirmation Token', token: '""')

      get :show, confirmation_token: '""'
    end

    it 'tracks already confirmed token' do
      user = create(:user, confirmation_token: 'foo')

      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: User Already Confirmed', user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end

    it 'tracks expired token' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo', confirmation_sent_at: Time.current - 2.days)

      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: token expired', user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('GET Request', controller: 'confirmations', action: 'show')
      expect(@analytics).to receive(:track_event).
        with('Email Confirmation: valid token', user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'initial password creation' do
    it 'tracks a valid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Password Created and User Confirmed')

      patch :confirm, password_form: { password: 'NewVal!dPassw0rd' }, confirmation_token: 'foo'
    end

    it 'tracks an invalid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('Password Creation: invalid', user_id: user.uuid)

      patch :confirm, password_form: { password: 'NewVal' }, confirmation_token: 'foo'
    end

    context 'user supplies invalid password' do
      it 'calls PasswordForm#submit' do
        form = instance_double(PasswordForm)
        allow(PasswordForm).to receive(:new).and_return(form)

        expect(form).to receive(:submit).with(password: 'password')

        patch :confirm, password_form: { password: 'password' }, confirmation_token: 'foo'
      end
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

      expect(@analytics).to receive(:track_event).
        with('GET Request', controller: 'confirmations', action: 'show')
      expect(@analytics).to receive(:track_event).
        with('Email changed and confirmed', user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end
end
