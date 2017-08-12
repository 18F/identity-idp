require 'rails_helper'

describe 'routes that require admin + 2FA' do
  def sign_in_user(user)
    post(
      new_user_session_path,
      params: { user: { email: user.email, password: user.password } }
    )
    get otp_send_path, params: { otp_delivery_selection_form: { otp_delivery_preference: 'sms' } }
    follow_redirect!
    post(
      login_two_factor_path,
      params: { otp_delivery_preference: 'sms', code: user.reload.direct_otp }
    )
  end

  shared_examples 'constrained route' do |endpoint|
    context 'user is signed in via 2FA but is not an admin' do
      it 'does not allow access' do
        user = create(:user, :signed_up)
        sign_in_user(user)

        get endpoint

        expect(response.body).
          to match('The page you were looking for doesn&#39;t exist')
      end
    end

    context 'user is an admin but is not signed in via 2FA' do
      it 'prompts admin to 2FA' do
        user = create(:user, :signed_up, :admin)

        post(
          new_user_session_path,
          params: { user: { email: user.email, password: user.password } }
        )

        get endpoint

        expect(response.status).to eq 404
      end
    end

    context 'user is an admin and is signed in via 2FA' do
      it 'allows access' do
        user = create(:user, :signed_up, :admin)
        sign_in_user(user)

        get endpoint

        expect(response.body).
          to_not match('The page you were looking for doesn&#39;t exist')
      end
    end
  end

  it_behaves_like 'constrained route', '/sidekiq'
end
