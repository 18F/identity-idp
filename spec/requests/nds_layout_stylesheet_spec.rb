require 'rails_helper'

RSpec.describe 'NDS layout stylesheet swap', type: :request do
  context 'default bucket' do
    it 'renders the legacy application stylesheet, not nds_application' do
      get root_url

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/application[-.]})
      expect(response.body).not_to include('nds_application')
    end

    it 'preloads public-sans fonts, not inter/InterVariable' do
      get root_url

      expect(response.body).to include('public-sans/PublicSans')
      expect(response.body).not_to include('inter/InterVariable')
    end

    it 'loads the legacy utilities and print bundles, not the nds variants' do
      get root_url

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/utilities[-.]})
      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/print[-.]})
      expect(response.body).not_to include('nds_utilities')
      expect(response.body).not_to include('nds_print')
    end
  end

  context 'forced nds bucket' do
    it 'renders the nds_application stylesheet via the nds base layout' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_application[-.]})
    end

    it 'preloads inter/InterVariable, not public-sans/PublicSans' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to include('inter/InterVariable')
      expect(response.body).not_to include('public-sans/PublicSans')
    end

    it 'loads the nds_utilities and nds_print bundles, not the legacy variants' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_utilities[-.]})
      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_print[-.]})
      expect(response.body).not_to match(%r{stylesheet["'][^>]*/assets/utilities[-.]})
      expect(response.body).not_to match(%r{stylesheet["'][^>]*/assets/print[-.]})
    end
  end
end
