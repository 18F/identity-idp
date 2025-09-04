require 'rails_helper'

RSpec.describe Api::SecuredData::ConfigurationController do
  let(:enabled) { false }

  before do
    allow(IdentityConfig.store).to receive(:secured_data_api_enabled).and_return(enabled)
  end

  describe '#index' do
    let(:action) { get :index }

    context 'when the Secured Data API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Secured Data API is enabled' do
      let(:enabled) { true }
      let(:json_response) { JSON.parse(response.body).with_indifferent_access }

      it 'returns 200 status' do
        expect(action.status).to eq(200)
      end

      it 'renders the secured data configuration' do
        action

        expect(json_response).to eq(SecuredDataConfigurationPresenter.new.configuration.as_json)
      end
    end
  end
end
