require 'rails_helper'

RSpec.describe OpenidConnect::AuthorizationController do
  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:params) do
    {
      acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      client_id: client_id,
      nonce:  SecureRandom.hex,
      prompt: 'select_account',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      response_type: 'code',
      scope: 'openid profile',
      state:  SecureRandom.hex,
    }
  end

  describe '#index' do
    subject(:action) { get :index, params }

    context 'user is signed in' do
      let(:user) { create(:user, :signed_up) }
      before do
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

        context 'with loa3 requested' do
          before { params[:acr_values] = Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF }

          context 'account is already verified' do
            let(:user) { create(:profile, :active, :verified).user }

            it 'renders the approve/deny form' do
              action
              expect(controller).to render_template('openid_connect/authorization/index')
            end
          end

          context 'account is not already verified' do
            it 'redirects to have the user verify their account' do
              action
              expect(controller).to redirect_to(verify_url)
            end
          end
        end

        context 'user has already approved this application' do
          before do
            IdentityLinker.new(user, client_id).link_identity
          end

          it 'redirects to the redirect_uri immediately' do
            action

            expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
          end
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
                 errors: {
                   state: ['Please fill in this field.', 'is too short (minimum is 32 characters)'],
                 })

          action
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects to SP landing page with the request_id in the params' do
        action
        sp_request_id = ServiceProviderRequest.last.uuid

        expect(response).to redirect_to sign_up_start_url(request_id: sp_request_id)
      end

      it 'sets sp information in the session' do
        action
        sp_request_id = ServiceProviderRequest.last.uuid

        expect(session[:sp]).to eq(
          loa3: false,
          issuer: 'urn:gov:gsa:openidconnect:test',
          request_id: sp_request_id,
          request_url: request.original_url,
          requested_attributes: %w[given_name family_name birthdate]
        )
      end
    end
  end

  describe '#create' do
    subject(:action) { post :create }

    context 'user is signed in' do
      before do
        user = create(:user, :signed_up)
        stub_sign_in user
        controller.user_session[:openid_auth_request] = params
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
    subject(:action) { delete :destroy }

    before { stub_analytics }

    context 'user is signed in' do
      before do
        user = create(:user, :signed_up)
        stub_sign_in user
        controller.user_session[:openid_auth_request] = params
      end

      it 'tracks the decline event' do
        stub_analytics
        expect(@analytics).to receive(:track_event).
          with(Analytics::OPENID_CONNECT_DECLINE, client_id: client_id)

        action
      end

      it 'redirects back to the client app with a access_denied' do
        action

        redirect_params = URIService.params(response.location)

        expect(redirect_params[:error]).to eq('access_denied')
        expect(redirect_params[:state]).to eq(params[:state])
      end

      context 'with invalid params' do
        before { params.delete(:redirect_uri) }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end
      end
    end

    context 'user is not signed in' do
      it 'redirects to login' do
        expect(action).to redirect_to(root_url)
      end
    end
  end
end
