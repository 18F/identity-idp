require 'rails_helper'

RSpec.describe CountrySupportController do
  describe '#index' do
    it 'renders country support as JSON' do
      get :index

      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:countries][:US]).to eq(
        name: 'United States',
        country_code: '1',
        supports_sms: true,
        supports_voice: true,
      )
    end

    it 'sets HTTP headers to cache for 15 minutes' do
      get :index

      expect(response['Cache-Control']).to eq("max-age=#{15.minutes.to_i}, public")
    end
  end
end
