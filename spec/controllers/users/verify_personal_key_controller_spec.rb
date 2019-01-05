require 'rails_helper'

describe Users::VerifyPersonalKeyController do
  let(:user) { create(:user, profiles: profiles, personal_key: personal_key) }
  let(:profiles) { [] }
  let(:personal_key) { 'key' }

  before { stub_sign_in(user) }

  describe 'before actions' do
    it 'only allows 2fa users through' do
      expect(subject).to have_actions(:confirm_two_factor_authenticated)
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
      let(:profiles) { [create(:profile, deactivation_reason: :password_reset)] }

      it 'renders the `new` template' do
        get :new

        expect(response).to render_template(:new)
      end

      it 'displays a flash message to the user' do
        get :new

        expect(subject.flash[:notice]).to eq(t('notices.account_reactivation'))
      end
    end
  end

  describe '#create' do
    let(:profiles) { [create(:profile, deactivation_reason: :password_reset)] }
    let(:form) { instance_double(VerifyPersonalKeyForm) }
    let(:error_text) { 'bad_key' }
    let(:personal_key_error) { { personal_key: [error_text] } }
    let(:response_ok) { FormResponse.new(success: true, errors: {}) }
    let(:response_bad) { FormResponse.new(success: false, errors: personal_key_error, extra: {}) }

    context 'wth a valid form' do
      before do
        allow(VerifyPersonalKeyForm).to receive(:new).
          with(user: subject.current_user, personal_key: personal_key).
          and_return(form)
        allow(form).to receive(:submit).and_return(response_ok)
      end

      it 'redirects to the next step of the account recovery flow' do
        post :create, params: { personal_key: personal_key }

        expect(response).to redirect_to(verify_password_url)
      end

      it 'stores that the personal key was entered in the user session' do
        post :create, params: { personal_key: personal_key }

        expect(subject.reactivate_account_session.personal_key?).to eq(true)
      end
    end

    context 'with an invalid form' do
      let(:bad_key) { 'baaad' }

      before do
        allow(VerifyPersonalKeyForm).to receive(:new).
          with(user: subject.current_user, personal_key: bad_key).
          and_return(form)
        allow(form).to receive(:submit).and_return(response_bad)
        post :create, params: { personal_key: bad_key }
      end

      it 'sets an error in the flash' do
        expect(flash[:error]).to eq(error_text)
      end

      it 'renders the new template' do
        expect(response).to render_template(:new)
      end
    end
  end
end
