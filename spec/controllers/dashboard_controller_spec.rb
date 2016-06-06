require 'rails_helper'

describe DashboardController do
  describe '#index' do
    let(:user) { create(:user, :signed_up) }

    before { sign_in user }

    after { session[:declined_quiz] = nil }

    context 'when quiz has been declined' do
      it 'does not redirect to quiz' do
        session[:declined_quiz] = true
        get :index

        expect(response).to_not be_redirect
      end
    end
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_filters(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end
end
