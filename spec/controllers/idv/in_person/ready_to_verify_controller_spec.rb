require 'rails_helper'

describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_sign_in(user)
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(:before, :confirm_two_factor_authenticated)
    end
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'redirects to account page' do
      expect(response).to redirect_to account_url
    end

    context 'with in person proofing component' do
      before do
        ProofingComponent.create(user: user, document_check: DocAuth::Vendors::USPS)
      end

      it 'renders show template' do
        expect(response).to render_template :show
      end

      it 'logs analytics' do
        response

        expect(@analytics).to have_logged_event('IdV: in person ready to verify visited')
      end
    end
  end
end
