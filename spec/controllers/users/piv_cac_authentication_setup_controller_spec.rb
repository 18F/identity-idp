require 'rails_helper'

describe Users::PivCacAuthenticationSetupController do

  describe 'when not signed in' do
    describe 'GET index' do
      it 'redirects to root url' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    describe 'DELETE delete' do
      it 'redirects to root url' do
        delete :delete

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when signed out' do
    describe 'GET index' do
      it 'redirects to sign in page' do
        get :new

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  describe 'when signing in' do
    before(:each) { sign_in_before_2fa(user) }
    let(:user) do
      create(:user, :signed_up, :with_piv_or_cac,
        phone: '+1 (555) 555-0000'
      )
    end

    describe 'GET index' do
      it 'redirects to 2fa entry' do
        get :new
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    describe 'DELETE delete' do
      it 'redirects to root url' do
        delete :delete
        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end
  end

  describe 'when signed in' do
    before(:each) { sign_in(user) }

    context 'without associated piv/cac' do
      let(:user) do
        create(:user, :signed_up,
          phone: '+1 (555) 555-0000'
        )
      end

      before(:each) do
        allow(PivCacService).to receive(:decode_token).with(good_token) { good_token_response }
        allow(PivCacService).to receive(:decode_token).with(bad_token) { bad_token_response }
        allow(subject).to receive(:user_session).and_return(piv_cac_nonce: nonce)
      end

      let(:nonce) { 'nonce' }

      let(:good_token) { 'good-token' }
      let(:good_token_response) do
        {
          'dn' => 'some dn',
          'uuid' => 'some-random-string',
          'nonce' => nonce,
        }
      end

      let(:bad_token) { 'bad-token' }
      let(:bad_token_response) do
        {
          'error' => 'certificate.bad' ,
          'nonce' => nonce,
        }
      end

      describe 'GET index' do
        context 'when rendered without a token' do
          it 'renders the "new" template' do
            get :new
            expect(response).to render_template(:new)
          end
        end

        context 'when redirected with a good token' do
          it 'redirects to account page' do
            get :new, params: {token: good_token}
            expect(response).to redirect_to(account_url)
          end
        end

        context 'when redirected with an error token' do
          it 'renders the error template' do
            get :new, params: {token: bad_token}
            expect(response).to render_template(:error)
          end
        end
      end

      describe 'DELETE delete' do
        it 'redirects to account page' do
          delete :delete
          expect(response).to redirect_to(account_url)
        end
      end
    end

    context 'with associated piv/cac' do
      let(:user) { create(:user, :with_piv_or_cac) }

      describe 'GET index' do
        it 'redirects to account page' do
          get :new
          expect(response).to redirect_to(account_url)
        end
      end

      describe 'DELETE delete' do
        it 'redirects to account page' do
          delete :delete
          expect(response).to redirect_to(account_url)
        end

        it 'removes the piv/cac association' do
          delete :delete
          expect(user.reload.x509_dn_uuid).to be_nil
        end
      end
    end
  end
end
