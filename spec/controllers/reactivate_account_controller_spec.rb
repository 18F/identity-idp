require 'rails_helper'

describe ReactivateAccountController do
  let(:user) { create(:user, profiles: profiles) }
  let(:profiles) { [] }

  before { stub_sign_in(user) }

  describe 'before_actions' do
    it 'requires the user to be logged in' do
      expect(subject).to have_actions(
        :confirm_two_factor_authenticated
      )
    end
  end

  describe '#index' do
    context 'with a password reset profile' do
      let(:profiles) { [create(:profile, deactivation_reason: :password_reset)] }

      it 'renders the index template' do
        get :index

        expect(subject).to render_template(:index)
      end
    end

    context 'wthout a password reset profile' do
      let(:profiles) { [create(:profile, :active)] }
      it 'redirects to the root url' do
        get :index

        expect(response).to redirect_to root_url
      end
    end
  end

  describe '#update' do
    let(:profiles) { [create(:profile, deactivation_reason: :password_reset)] }

    it 'redirects user to idv_url' do
      put :update

      expect(subject.user_session[:acknowledge_personal_key]).to be_nil
      expect(response).to redirect_to idv_url
    end
  end
end
