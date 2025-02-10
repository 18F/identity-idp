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

      expect(response['Cache-Control']).to eq("max-age=#{15.minutes.in_seconds}, public")
    end

    context 'renders when passing in different locale' do
      it 'renders country support with localization support' do
        get :index, params: { locale: 'es' }

        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:countries][:US]).to eq(
          name: 'Estados Unidos',
          country_code: '1',
          supports_sms: true,
          supports_voice: true,
        )
      end
    end
  end
end
