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
    subject(:action) { get :index, params: params }

    context 'user is signed in' do
      let(:user) { create(:user, :signed_up) }
      before do
        stub_sign_in user
      end

      context 'with valid params' do
        it 'redirects back to the client app with a code' do
          IdentityLinker.new(user, client_id).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = URIService.params(response.location)

          expect(redirect_params[:code]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'tracks the event' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                 success: true,
                 client_id: client_id,
                 errors: {},
                 user_fully_authenticated: true)

          action
        end

        context 'with loa3 requested' do
          before { params[:acr_values] = Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF }

          context 'account is already verified' do
            let(:user) { create(:profile, :active, :verified).user }

            it 'redirects to the redirect_uri immediately' do
              IdentityLinker.new(user, client_id).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate]
              )
              action

              expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
            end
          end

          context 'account is not already verified' do
            it 'redirects to have the user verify their account' do
              action
              expect(controller).to redirect_to(idv_url)
            end
          end
        end

        context 'user has not approved this application' do
          it 'redirects verify shared attributes page' do
            action

            expect(response).to redirect_to(sign_up_completed_url)
          end

          it 'links identity to the user' do
            action
            sp = user.identities.last.service_provider
            expect(sp).to eq(params[:client_id])
          end
        end

        context 'user has already approved this application' do
          before do
            IdentityLinker.new(user, client_id).link_identity
            user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])
          end

          it 'redirects back to the client app with a code' do
            action

            expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

            redirect_params = URIService.params(response.location)

            expect(redirect_params[:code]).to be_present
            expect(redirect_params[:state]).to eq(params[:state])
          end
        end
      end

      context 'with invalid params that do not interfere with the redirect_uri' do
        before { params[:prompt] = '' }

        it 'redirects to the redirect_uri immediately with an invalid_request' do
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)

          redirect_params = URIService.params(response.location)

          expect(redirect_params[:error]).to eq('invalid_request')
          expect(redirect_params[:error_description]).to be_present
          expect(redirect_params[:state]).to eq(params[:state])
        end

        it 'tracks the event with errors' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                 success: false,
                 client_id: client_id,
                 errors: hash_including(:prompt),
                 user_fully_authenticated: true)

          action
        end
      end

      context 'with invalid params that mean the redirect_uri is not trusted' do
        before { params.delete(:client_id) }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end

        it 'tracks the event with errors' do
          stub_analytics
          expect(@analytics).to receive(:track_event).
            with(Analytics::OPENID_CONNECT_REQUEST_AUTHORIZATION,
                 success: false,
                 client_id: nil,
                 errors: hash_including(:client_id),
                 user_fully_authenticated: true)

          action
        end
      end
    end

    context 'user is not signed in' do
      context 'without valid acr_values' do
        before { params.delete(:acr_values) }

        it 'handles the error and does not blow up' do
          action

          expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
        end
      end

      context 'with a bad redirect_uri' do
        before { params[:redirect_uri] = '!!!' }

        it 'renders the error page' do
          action
          expect(controller).to render_template('openid_connect/authorization/error')
        end
      end

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
end
