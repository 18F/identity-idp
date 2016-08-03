require 'rails_helper'

describe Users::PasswordsController, devise: true do
  describe 'Resetting password with valid password' do
    it 'tracks valid password reset event' do
      user = create(:user, :signed_up)

      raw_reset_token, db_confirmation_token =
        Devise.token_generator.generate(User, :reset_password_token)
      user.update(
        reset_password_token: db_confirmation_token,
        reset_password_sent_at: Time.zone.now
      )

      stub_analytics

      expect(@analytics).to receive(:track_event).with('Password reset', user)

      put(
        :update,
        password_form: { password: 'NewVal!dPassw0rd', reset_password_token: raw_reset_token }
      )
    end
  end
end
