require 'rails_helper'

describe SignUp::PasswordsController do
  describe '#create' do
    it 'tracks a valid password event' do
      token = 'new token'
      user = create(:user, confirmation_token: token, confirmation_sent_at: Time.zone.now)

      stub_analytics

      analytics_hash = {
        success: true,
        errors: {},
        user_id: user.uuid,
        request_id_present: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATION, analytics_hash)

      post :create, params: {
        password_form: { password: 'NewVal!dPassw0rd' },
        confirmation_token: token,
      }

      user.reload
      expect(user.valid_password?('NewVal!dPassw0rd')).to eq true
      expect(user.confirmed?).to eq true
      expect(user.reset_requested_at).to be_nil
    end

    it 'tracks an invalid password event' do
      token = 'new token'
      user = create(:user, confirmation_token: token, confirmation_sent_at: Time.zone.now)

      stub_analytics

      analytics_hash = {
        success: false,
        errors: { password: ['is too short (minimum is 9 characters)'] },
        user_id: user.uuid,
        request_id_present: false,
      }

      expect(@analytics).to receive(:track_event).
        with(Analytics::PASSWORD_CREATION, analytics_hash)

      post :create, params: { password_form: { password: 'NewVal' }, confirmation_token: token }
    end
  end

  describe '#new' do
    render_views
    it 'instructs crawlers to not index this page' do
      token = 'foo token'
      user = create(:user, :unconfirmed, confirmation_token: token, confirmation_sent_at: Time.zone.now)
      get :new, params: { confirmation_token: token }

      expect(response.body).to match('<meta content="noindex,nofollow" name="robots" />')
    end
  end
end
