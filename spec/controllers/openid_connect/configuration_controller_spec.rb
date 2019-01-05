require 'rails_helper'

RSpec.describe OpenidConnect::ConfigurationController do
  describe '#index' do
    let(:json_response) { JSON.parse(response.body).with_indifferent_access }

    it 'renders information about the OpenID Connect integration' do
      get :index

      expect(json_response).to eq(OpenidConnectConfigurationPresenter.new.configuration.as_json)
    end

    it 'sets HTTP headers to cache for a week' do
      get :index

      expect(response['Cache-Control']).to eq("max-age=#{1.week.to_i}, public")
    end
  end
end
