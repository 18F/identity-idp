require 'rails_helper'

describe TwoFactorAuthentication::PivCacVerificationController do
  let(:user) do
    create(:user, :signed_up, :with_piv_or_cac,
      phone: '+1 (555) 555-0000'
    )
  end

  let(:nonce) { 'once' }

  before(:each) do
    allow(subject).to receive(:user_session).and_return(piv_cac_nonce: nonce)
    allow(PivCacService).to receive(:decode_token).with('good-token').and_return(
      'uuid' => user.x509_dn_uuid,
      'dn' => 'bar',
      'nonce' => nonce,
    )
    allow(PivCacService).to receive(:decode_token).with('bad-token').and_return(
      'uuid' => 'bad-uuid',
      'dn' => 'bad-dn',
      'nonce' => nonce
    )
    allow(PivCacService).to receive(:decode_token).with('bad-nonce').and_return(
      'uuid' => user.x509_dn_uuid,
      'dn' => 'bar',
      'nonce' => 'bad-' + nonce
    )
  end

  describe '#show' do
    context 'before the user presents a valid PIV/CAC' do
      before(:each) do
        sign_in_before_2fa(user)
      end

      it 'renders a page with a submit button to capture the cert' do
        get :show

        expect(response).to render_template(:show)
      end
    end

    context 'when the user presents a valid PIV/CAC' do
      before(:each) do
        sign_in_before_2fa(user)
      end

      it 'redirects to the profile' do
        expect(subject.current_user).to receive(:confirm_piv_cac?).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0

        get :show, params: { token:  'good-token' }

        expect(response).to redirect_to account_path
      end

      it 'resets the second_factor_attempts_count' do
        UpdateUser.new(
          user: subject.current_user,
          attributes: { second_factor_attempts_count: 1 }
        ).call

        get :show, params: { token:  'good-token' }

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'tracks the valid authentication event' do
        stub_analytics
        attributes = {
          success: true,
          errors: {},
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
        }
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH, attributes)

        get :show, params: { token:  'good-token' }
      end
    end

    context 'when the user presents an invalid piv/cac' do
      before do
        sign_in_before_2fa(user)

        get :show, params: { token: 'bad-token' }
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 're-renders the piv/cac entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.invalid_piv_cac')
      end
    end

    context 'when the user has reached the max number of piv/cac attempts' do
      it 'tracks the event' do
        allow_any_instance_of(User).to receive(:max_login_attempts?).and_return(true)
        sign_in_before_2fa(user)

        stub_analytics

        attributes = {
          success: false,
          errors: {},
          context: 'authentication',
          multi_factor_auth_method: 'piv_cac',
        }

        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH, attributes)
        expect(@analytics).to receive(:track_event).with(Analytics::MULTI_FACTOR_AUTH_MAX_ATTEMPTS)

        get :show, params: { token: 'bad-token' }
      end
    end

    context 'when the user lockout period expires' do
      before(:each) do
        sign_in_before_2fa(user)
      end

      let(:lockout_period) { Figaro.env.lockout_period_in_minutes.to_i.minutes }

      let(:user) do
        create(:user, :signed_up, :with_piv_or_cac,
          second_factor_locked_at: Time.zone.now - lockout_period - 1.second,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits an incorrect piv/cac' do
        before(:each) do
          get :show, params: { token: 'bad-token' }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a valid piv/cac' do
        before do
          get :show, params: { token: 'good-token' }
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end

    context 'when the user does not have a piv/cac associated' do
      context 'and a token is provided' do
        it 'redirects to user_two_factor_authentication_path' do
          stub_sign_in_before_2fa
          get :show, params: { token: '123456' }

          expect(response).to redirect_to user_two_factor_authentication_path
        end
      end

      context 'and no token is provided' do
        it 'redirects to user_two_factor_authentication_path' do
          stub_sign_in_before_2fa
          get :show

          expect(response).to redirect_to user_two_factor_authentication_path
        end
      end
    end
  end
end
