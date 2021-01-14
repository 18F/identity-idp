require 'rails_helper'

describe 'requesting acuant SDK assets' do
  context 'with a valid Acuant SDK asset' do
    it 'renders a JS asset, without CSP headers or session cookie' do
      get '/acuant/11.4.1/AcuantImageProcessingWorker.min.js'

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/javascript')
      expect(response.headers['Content-Security-Policy']).to be_nil
      expect(response.cookies.keys).to_not include('_upaya_session')
      expect(response.body).to eq(
        File.read('public/acuant/11.4.1/AcuantImageProcessingWorker.min.js'),
      )
    end

    it 'renders a WASM asset, without CSP headers or session cookie' do
      get '/acuant/11.4.1/AcuantImageProcessingWorker.wasm'

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/wasm')
      expect(response.headers['Content-Security-Policy']).to be_nil
      expect(response.cookies.keys).to_not include('_upaya_session')
      expect(response.body.length).to eq(
        File.size('public/acuant/11.4.1/AcuantImageProcessingWorker.wasm'),
      )
    end
  end

  context 'with something that is not a valid Acuant SDK asset' do
    it 'renders a 404 and leaves in the CSP headers' do
      get '/acuant/11.4.1/something-that-does-not-exist/AcuantImageProcessingWorker.wasm'

      expect(response.status).to eq(404)
      expect(response.headers['Content-Security-Policy']).to be_present
    end

    it 'renders a 404 for map files' do
      get '/acuant/11.4.1/AcuantImageProcessingService.wasm.map'

      expect(response.status).to eq(404)
    end
  end
end
