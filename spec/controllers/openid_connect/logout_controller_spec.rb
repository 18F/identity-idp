require 'rails_helper'

RSpec.describe OpenidConnect::LogoutController do
  let(:state) { SecureRandom.hex }
  let(:code) { SecureRandom.uuid }
  let(:post_logout_redirect_uri) { 'gov.gsa.openidconnect.test://result/logout' }

  let(:user) { build(:user) }
  let(:service_provider) { 'urn:gov:gsa:openidconnect:test' }
  let(:identity) do
    create(:identity,
           service_provider: service_provider,
           user: user,
           access_token: SecureRandom.hex,
           session_uuid: SecureRandom.uuid)
  end

  let(:id_token_hint) do
    IdTokenBuilder.new(
      identity: identity,
      code: code,
      custom_expiration: 1.day.from_now.to_i
    ).id_token
  end

  describe '#index' do
    subject(:action) do
      get :index,
          params: {
            id_token_hint: id_token_hint,
            post_logout_redirect_uri: post_logout_redirect_uri,
            state: state,
          }
    end

    context 'user is signed in' do
      before { sign_in user }

      context 'with valid params' do
        it 'destroys the session' do
          expect(controller).to receive(:sign_out).and_call_original

          action
        end

        it 'redirects back to the client' do
          action

          expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
        end

        it 'tracks analytics' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_LOGOUT,
                 success: true, client_id: service_provider, errors: {})

          action
        end
      end

      context 'with a bad redirect URI' do
        let(:post_logout_redirect_uri) { 'https://example.com' }

        it 'renders an error page' do
          action

          expect(response).to render_template(:error)
        end

        it 'does not destroy the session' do
          expect(controller).to_not receive(:sign_out)

          action
        end

        it 'tracks analytics' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_LOGOUT,
                 success: false,
                 client_id: service_provider,
                 errors: hash_including(:post_logout_redirect_uri))

          action
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects back with an error' do
        action

        expect(response).to redirect_to(/^#{post_logout_redirect_uri}/)
      end
    end
  end
end
