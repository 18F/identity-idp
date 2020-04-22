require 'rails_helper'

describe 'requesting acuant SDK assets' do
  context 'with a valid Acuant SDK asset' do
    it 'renders a JS asset' do
      get '/verify/doc_auth/AcuantJavascriptWebSdk.min.js'

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/javascript')
      expect(response.body).to eq(File.read('public/AcuantJavascriptWebSdk.min.js'))
    end

    it 'renders a WASM asset' do
      get '/verify/doc_auth/AcuantImageProcessingService.wasm'

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/wasm')
      expect(response.body.length).to eq(File.size('public/AcuantImageProcessingService.wasm'))
    end

    it 'adds unsafe-eval to the CSP' do
      get '/verify/doc_auth/AcuantJavascriptWebSdk.min.js'

      expect(response.headers['Content-Security-Policy']).to match(/script-src[^;]*'unsafe-eval'/)
    end
  end

  context 'with something that is not a valid Acuant SDK asset' do
    it 'renders a 404' do
      get '/verify/doc_auth/uselss-noise.min.js'

      expect(response.status).to eq(404)
    end
  end
end
