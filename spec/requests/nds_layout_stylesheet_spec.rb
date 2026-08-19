require 'rails_helper'

RSpec.describe 'NDS layout stylesheet swap', type: :request do
  context 'default bucket' do
    it 'renders the legacy application stylesheet, not nds_application' do
      get root_url

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/application[-.]})
      expect(response.body).not_to include('nds_application')
    end
  end

  context 'forced nds bucket' do
    it 'renders the nds_application stylesheet via the nds base layout' do
      get root_url, params: { nds_bucket: 'nds' }

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_application[-.]})
    end
  end
end
