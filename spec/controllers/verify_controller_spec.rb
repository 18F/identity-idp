require 'rails_helper'

describe VerifyController do
  describe '#show' do
    subject(:response) { get :show }

    context 'with idv_api_enabled feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled).and_return(false)
      end

      it 'renders 404' do
        expect(response).to be_not_found
      end
    end

    context 'with idv_api_enabled feature enabled' do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled).and_return(true)
      end

      it 'renders view' do
        expect(response).to render_template(:show)
      end
    end
  end
end
