require 'rails_helper'

RSpec.describe OpenidConnect::AuthorizationController do
  before do
    # All the tests here were written prior to the interstitial
    # authorization confirmation page so let's force the system
    # to skip past that page
    allow(controller).to receive(:auth_count).and_return(2)
  end

  let(:client_id) { 'urn:gov:gsa:openidconnect:test' }
  let(:params) do
    {
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      client_id: client_id,
      nonce: SecureRandom.hex,
      prompt: 'select_account',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      response_type: 'code',
      scope: 'openid profile',
      state: SecureRandom.hex,
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
                 unauthorized_scope: true,
                 user_fully_authenticated: true)
          expect(@analytics).to receive(:track_event).with(Analytics::SP_REDIRECT_INITIATED)

          IdentityLinker.new(user, client_id).link_identity(ial: 1)
          user.identities.last.update!(verified_attributes: %w[given_name family_name birthdate])

          action
        end

        context 'with ial2 requested' do
          before { params[:acr_values] = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

          context 'account is already verified' do
            let(:user) { create(:profile, :active, :verified).user }

            it 'redirects to the redirect_uri immediately when pii is unlocked' do
              IdentityLinker.new(user, client_id).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(false)
              action

              expect(response).to redirect_to(/^#{params[:redirect_uri]}/)
            end

            it 'redirects to the password capture url when pii is locked' do
              IdentityLinker.new(user, client_id).link_identity(ial: 3)
              user.identities.last.update!(
                verified_attributes: %w[given_name family_name birthdate],
              )
              allow(controller).to receive(:pii_requested_but_locked?).and_return(true)
              action

              expect(response).to redirect_to(capture_password_url)
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

          it 'does not link identity to the user' do
            action
            expect(user.identities.count).to eq(0)
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
                 unauthorized_scope: true,
                 errors: hash_including(:prompt),
                 user_fully_authenticated: true)
          expect(@analytics).to_not receive(:track_event).with(Analytics::SP_REDIRECT_INITIATED)

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
                 unauthorized_scope: true,
                 errors: hash_including(:client_id),
                 user_fully_authenticated: true)
          expect(@analytics).to_not receive(:track_event).with(Analytics::SP_REDIRECT_INITIATED)

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

        expect(response).to redirect_to new_user_session_url(request_id: sp_request_id)
      end

      it 'sets sp information in the session and does not transmit ial2 attrs for ial1' do
        action
        sp_request_id = ServiceProviderRequest.last.uuid

        expect(session[:sp]).to eq(
          ial2: false,
          issuer: 'urn:gov:gsa:openidconnect:test',
          request_id: sp_request_id,
          request_url: request.original_url,
          requested_attributes: %w[],
        )
      end
    end
  end
end
