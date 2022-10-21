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
      let!(:profiles) { [create(:profile, :password_reset, user: user)] }

      it 'renders the `new` template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'displays a flash message to the user' do
        get :new

        expect(subject.flash[:info]).to eq(t('notices.account_reactivation'))
      end

      it 'shows throttled page after being throttled' do
        Throttle.new(throttle_type: :verify_personal_key, user: user).increment_to_throttled!

        get :new

        expect(response).to render_template(:throttled)
      end
    end

    context 'with throttle reached' do
      let!(:profiles) { [create(:profile, :password_reset, user: user)] }

      before do
        Throttle.new(throttle_type: :verify_personal_key, user: user).increment_to_throttled!
      end

      it 'renders throttled page' do
        stub_analytics
        stub_attempts_tracker
        expect(@analytics).to receive(:track_event).with(
          'Personal key reactivation: Personal key form visited',
        ).once
        expect(@analytics).to receive(:track_event).with(
          'Throttler Rate Limit Triggered',
          throttle_type: :verify_personal_key,
        ).once

        expect(@irs_attempts_api_tracker).not_to receive(:personal_key_reactivation_rate_limited)

        get :new

        expect(response).to render_template(:throttled)
      end
    end
  end

  describe '#create' do
    let!(:profiles) do
      [
        create(
          :profile,
          :password_reset,
          user: user,
          pii: { ssn: '123456789' },
        ),
      ]
    end
    let(:error_text) { 'Incorrect personal key' }
    let(:personal_key_bad_params) { { personal_key: 'baaad' } }
    let(:personal_key_error) { { personal_key: [error_text] } }
    let(:failure_properties) { { success: false, failure_reason: personal_key_error } }
    let(:pii_like_keypaths_errors) { [[:errors, :personal_key], [:error_details, :personal_key]] }
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
          'Personal key reactivation: Personal key form submitted',
          errors: {},
          success: true,
          pii_like_keypaths: pii_like_keypaths_errors,
        ).once

        expect(@analytics).to receive(:track_event).with(
          'Personal key reactivation: Account reactivated with personal key',
        ).once

        post :create, params: { personal_key: profiles.first.personal_key }

        expect(subject.reactivate_account_session.validated_personal_key?).to eq(true)
      end

      it 'tracks irs attempts api for relevant users' do
        stub_attempts_tracker

        expect(@irs_attempts_api_tracker).to receive(:personal_key_reactivation_submitted).with(
          failure_reason: nil,
          success: true,
        ).once

        post :create, params: { personal_key: profiles.first.personal_key }

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

      it 'tracks irs attempts api for relevant users' do
        stub_attempts_tracker

        expect(@irs_attempts_api_tracker).to receive(:personal_key_reactivation_submitted).with(
          failure_properties,
        ).once

        allow_any_instance_of(VerifyPersonalKeyForm).to receive(:submit).and_return(response_bad)

        post :create, params: personal_key_bad_params
      end
    end

    context 'with throttle reached' do
      it 'renders throttled page' do
        stub_analytics
        stub_attempts_tracker
        expect(@analytics).to receive(:track_event).with(
          'Personal key reactivation: Personal key form submitted',
          errors: { personal_key: ['Please fill in this field.', error_text] },
          error_details: { personal_key: [:blank, :personal_key_incorrect] },
          success: false,
          pii_like_keypaths: pii_like_keypaths_errors,
        ).once
        expect(@analytics).to receive(:track_event).with(
          'Throttler Rate Limit Triggered',
          throttle_type: :verify_personal_key,
        ).once

        expect(@irs_attempts_api_tracker).to receive(:personal_key_reactivation_rate_limited).once

        max_attempts = Throttle.max_attempts(:verify_personal_key)
        (max_attempts + 1).times { post :create, params: personal_key_bad_params }

        expect(response).to render_template(:throttled)
      end

      it 'tracks irs attempts api for relevant users' do
        stub_attempts_tracker

        expect(@irs_attempts_api_tracker).to receive(:personal_key_reactivation_submitted).with(
          failure_properties,
        ).once

        allow_any_instance_of(VerifyPersonalKeyForm).to receive(:submit).and_return(response_bad)

        post :create, params: personal_key_bad_params
      end
    end
  end
end
