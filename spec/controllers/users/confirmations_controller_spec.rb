require 'rails_helper'

describe Users::ConfirmationsController, devise: true do
  describe 'Invalid email confirmation tokens' do
    before do
      stub_analytics
    end

    it 'tracks nil email confirmation token' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_INVALID_TOKEN, token: 'nil')

      get :show, confirmation_token: nil
    end

    it 'tracks blank email confirmation token' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_INVALID_TOKEN, token: '')

      get :show, confirmation_token: ''
    end

    it 'tracks confirmation token as a single-quoted empty string' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_INVALID_TOKEN, token: "''")

      get :show, confirmation_token: "''"
    end

    it 'tracks confirmation token as a double-quoted empty string' do
      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_INVALID_TOKEN, token: '""')

      get :show, confirmation_token: '""'
    end

    it 'tracks already confirmed token' do
      user = create(:user, confirmation_token: 'foo')

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_USER_ALREADY_CONFIRMED, user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end

    it 'tracks expired token' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo', confirmation_sent_at: Time.current - 2.days)

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_TOKEN_EXPIRED, user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'Valid email confirmation tokens' do
    it 'tracks a valid email confirmation token event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::EMAIL_CONFIRMATION_VALID_TOKEN, user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end

  describe 'initial password creation' do
    it 'tracks a valid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATE_USER_CONFIRMED)

      patch :confirm, password_form: { password: 'NewVal!dPassw0rd' }, confirmation_token: 'foo'
    end

    it 'tracks an invalid password event' do
      user = create(:user, :unconfirmed)
      user.update(confirmation_token: 'foo')

      stub_analytics

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATE_INVALID, user_id: user.uuid)

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
        with(Analytics::EMAIL_CHANGED_AND_CONFIRMED, user_id: user.uuid)

      get :show, confirmation_token: 'foo'
    end
  end
end
