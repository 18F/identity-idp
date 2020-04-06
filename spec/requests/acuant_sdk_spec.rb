require 'rails_helper'

describe 'requesting acuant SDK assets' do
  context 'with a valid Acuant SDK asset' do
    it 'renders the asset' do
      get '/verify/doc_auth/AcuantJavascriptWebSdk.min.js'

      expect(response.status).to eq(200)
      expect(response.content_type).to eq('text/javascript')
      expect(response.body).to eq(File.read('public/AcuantJavascriptWebSdk.min.js'))
    end
  end

  context 'with something that is not a valid Acuant SDK asset' do
    it 'renders a 404' do
      get '/verify/doc_auth/uselss-noise.min.js'

      expect(response.status).to eq(404)
    end
  end
end
