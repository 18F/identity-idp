require 'rails_helper'

describe Users::VerifyPersonalKeyController do
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
      let!(:profiles) { [create(:profile, user: user, deactivation_reason: :password_reset)] }

      it 'renders the `new` template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'displays a flash message to the user' do
        get :new

        expect(subject.flash[:info]).to eq(t('notices.account_reactivation'))
      end

      it 'shows throttled page after being throttled' do
        create(:throttle, :with_throttled, user: user, throttle_type: :verify_personal_key)

        get :new

        expect(response).to render_template(:throttled)
      end
    end

    context 'with throttle reached' do
      let!(:profiles) { [create(:profile, user: user, deactivation_reason: :password_reset)] }

      before do
        create(:throttle, :with_throttled, user: user, throttle_type: :verify_personal_key)
      end

      it 'renders throttled page' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          Analytics::PERSONAL_KEY_REACTIVATION_VISITED,
        ).once
        expect(@analytics).to receive(:track_event).with(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :verify_personal_key,
        ).once

        get :new

        expect(response).to render_template(:throttled)
      end
    end
  end

  describe '#create' do
    let!(:profiles) {
      [
        create(
          :profile,
          user: user, deactivation_reason: :password_reset,
          pii: { ssn: '123456789' }
        ),
      ]
    }
    let(:error_text) { 'Incorrect personal key' }
    let(:personal_key_error) { { personal_key: [error_text] } }
    let(:response_ok) { FormResponse.new(success: true, errors: {}) }
    let(:response_bad) { FormResponse.new(success: false, errors: personal_key_error, extra: {}) }

    context 'with a valid form' do
      it 'redirects to the next step of the account recovery flow' do
        post :create, params: { personal_key: profiles.first.personal_key }

        expect(response).to redirect_to(verify_password_url)
      end

      it 'stores that the personal key was entered in the user session' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          Analytics::PERSONAL_KEY_REACTIVATION_SUBMITTED,
          { errors: {}, success: true },
        ).once

        expect(@analytics).to receive(:track_event).with(
          Analytics::PERSONAL_KEY_REACTIVATION,
        ).once

        post :create, params: { personal_key: profiles.first.personal_key }

        expect(subject.reactivate_account_session.personal_key?).to eq(true)
      end
    end

    context 'with an invalid form' do
      let(:bad_key) { 'baaad' }

      before do
        post :create, params: { personal_key: bad_key }
      end

      it 'sets an error in the flash' do
        expect(flash[:error]).to eq(error_text)
      end

      it 'redirects to form' do
        expect(response).to redirect_to(verify_personal_key_url)
      end
    end

    context 'with throttle reached' do
      let(:bad_key) { 'baaad' }

      it 'renders throttled page' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          Analytics::PERSONAL_KEY_REACTIVATION_SUBMITTED,
          errors: { personal_key: ['Please fill in this field.', 'Incorrect personal key'] },
          error_details: { personal_key: [:blank, :personal_key_incorrect] },
          success: false,
        ).once
        expect(@analytics).to receive(:track_event).with(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :verify_personal_key,
        ).once

        max_attempts = Throttle.max_attempts(:verify_personal_key)
        (max_attempts + 1).times { post :create, params: { personal_key: bad_key } }

        expect(response).to render_template(:throttled)
      end
    end
  end
end
