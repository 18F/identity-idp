require 'rails_helper'

describe SignUp::PasswordsController do
  describe '#create' do
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

      post :create, password_form: { password: 'NewVal!dPassw0rd' }, confirmation_token: token

      user.reload
      expect(user.valid_password?('NewVal!dPassw0rd')).to eq true
      expect(user.confirmed?).to eq true
      expect(user.reset_requested_at).to be_nil
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

      post :create, password_form: { password: 'NewVal' }, confirmation_token: token
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

      post :create, password_form: { password: 'password' }, confirmation_token: 'foo'
    end
  end
end
