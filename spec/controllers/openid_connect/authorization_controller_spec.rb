require 'rails_helper'

RSpec.describe OpenidConnect::AuthorizationController do
  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:params) do
    {
      acr_values: 'http://idmanagement.gov/ns/assurance/loa/1',
      client_id: client_id,
      nonce:  SecureRandom.hex,
      prompt: 'select_account',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      response_type: 'code',
      scope: 'openid profile',
      state:  SecureRandom.hex
    }
  end

  describe '#index' do
    subject(:action) { get :index, params }

    context 'user is signed in' do
      before do
        user = create(:user, :signed_up)
        stub_sign_in user
      end

      context 'with valid params' do
        it 'renders the approve/deny form' do
          action
          expect(controller).to render_template('openid_connect/authorization/index')
        end

        it 'tracks the event' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                 success: true,
                 client_id: client_id,
                 errors: {})

          action
        end
      end

      context 'with invalid params' do
        before { params.delete(:state) }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end

        it 'tracks the event with errors' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                 success: false,
                 client_id: client_id,
                 errors: { state: ['Please fill in this field.'] })

          action
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects to login' do
        expect(action).to redirect_to(root_url)
      end
    end
  end

  describe '#create' do
    subject(:action) { post :create, params }

    context 'user is signed in' do
      before do
        user = create(:user, :signed_up)
        stub_sign_in user
      end

      it 'tracks the allow event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_ALLOW, success: true, client_id: client_id, errors: {})

        action
      end

      context 'with invalid params' do
        before { params.delete(:redirect_uri) }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end

        it 'tracks the allow event with success: false' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_ALLOW,
                 success: false,
                 client_id: client_id,
                 errors: hash_including(:redirect_uri))

          action
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects to login' do
        expect(action).to redirect_to(root_url)
      end
    end
  end

  describe '#destroy' do
    subject(:action) { delete :destroy, params }

    before { stub_analytics }

    context 'user is signed in' do
      before do
        user = create(:user, :signed_up)
        stub_sign_in user
      end

      it 'tracks the decline event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_DECLINE, client_id: client_id)

        action
      end
    end

    context 'user is not signed in' do
      it 'redirects to login' do
        expect(action).to redirect_to(root_url)
      end
    end
  end
end
