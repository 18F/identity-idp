require 'rails_helper'

describe Idv::InPerson::ReadyToVerifyController do
  let(:user) { nil }

  before do
    stub_sign_in(user) if user
  end

  describe '#show' do
    subject(:response) { get :show }

    it 'redirects to sign-in page' do
      expect(response).to redirect_to root_url
    end

    context 'signed in' do
      let(:user) { create(:user) }

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
      end
    end
  end
end
