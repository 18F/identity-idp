require 'rails_helper'

RSpec.describe Users::VerifyPersonalKeyController do
  let(:user) { create(:user, personal_key: personal_key) }
  let!(:profiles) { [] }
  let(:personal_key) { 'key' }

  before { stub_sign_in(user) }

  describe 'before actions' do
    it 'only allows 2fa users through' do
      expect(subject).to have_actions(:before, :confirm_two_factor_authenticated)
    end
  end

  describe '#new' do
    context 'without password_reset_profile' do
      it 'redirects user to the home page' do
        get :new
        expect(response).to redirect_to(root_url)
      end
    end

    context 'with password reset profile' do
      let!(:profiles) { [create(:profile, :verified, :password_reset, user: user)] }

      it 'renders the `new` template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'displays a flash message to the user' do
        get :new

        expect(subject.flash[:info]).to eq(t('notices.account_reactivation'))
      end

      it 'shows rate limited page after being rate limited' do
        RateLimiter.new(rate_limit_type: :verify_personal_key, user: user).increment_to_limited!

        get :new

        expect(response).to render_template(:rate_limited)
      end
    end

    context 'with rate limit reached' do
      let!(:profiles) { [create(:profile, :verified, :password_reset, user: user)] }

      before do
        RateLimiter.new(rate_limit_type: :verify_personal_key, user: user).increment_to_limited!
      end

      it 'renders rate limited page' do
        stub_analytics

        get :new

        expect(@analytics).to have_logged_event(
          'Personal key reactivation: Personal key form visited',
        )
        expect(@analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :verify_personal_key,
        )
        expect(response).to render_template(:rate_limited)
      end
    end
  end

  describe '#create' do
    let!(:profiles) do
      [
        create(
          :profile,
          :verified,
          :password_reset,
          user: user,
          pii: { ssn: '123456789' },
        ),
      ]
    end
    let(:error_text) { 'Incorrect personal key' }
    let(:personal_key_bad_params) { { personal_key: 'baaad' } }
    let(:personal_key_error) { { personal_key: [error_text] } }
    let(:failure_properties) { { success: false } }
    let(:response_ok) { FormResponse.new(success: true, errors: {}) }
    let(:response_bad) { FormResponse.new(success: false, errors: personal_key_error, extra: {}) }

    context 'with a valid form' do
      it 'redirects to the next step of the account recovery flow' do
        post :create, params: { personal_key: profiles.first.personal_key }

        expect(response).to redirect_to(verify_password_url)
      end

      it 'stores that the personal key was entered in the user session' do
        stub_analytics

        post :create, params: { personal_key: profiles.first.personal_key }

        expect(@analytics).to have_logged_event(
          'Personal key reactivation: Personal key form submitted',
          success: true,
        )
        expect(@analytics).to have_logged_event(
          'Personal key reactivation: Account reactivated with personal key',
        )
        expect(subject.reactivate_account_session.validated_personal_key?).to eq(true)
      end
    end

    context 'with an invalid form' do
      it 'sets an error in the flash' do
        post :create, params: personal_key_bad_params

        expect(flash[:error]).to eq(error_text)
      end

      it 'redirects to form' do
        post :create, params: personal_key_bad_params
        expect(response).to redirect_to(verify_personal_key_url)
      end
    end

    context 'with rate limit reached' do
      it 'renders rate limited page' do
        stub_analytics

        max_attempts = RateLimiter.max_attempts(:verify_personal_key)
        max_attempts.times { post :create, params: personal_key_bad_params }

        expect(@analytics).to have_logged_event(
          'Personal key reactivation: Personal key form submitted',
          errors: { personal_key: ['Please fill in this field.', error_text] },
          error_details: { personal_key: { blank: true, personal_key: true } },
          success: false,
        )
        expect(@analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :verify_personal_key,
        )
        expect(response).to render_template(:rate_limited)
      end
    end
  end
end
