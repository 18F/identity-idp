require 'rails_helper'

describe 'requesting acuant SDK assets' do
  context 'with a valid Acuant SDK asset' do
    [nil, *I18n.available_locales].each do |locale|
      context "with locale prefix: #{locale || '(none)'}" do
        it 'renders a JS asset' do
          get "/#{locale}/verify/doc_auth/AcuantImageProcessingWorker.min.js"

          expect(response.status).to eq(200)
          expect(response.headers['Content-Type']).to eq('application/javascript')
          expect(response.body).to eq(
            File.read('public/acuant/11.4.1/AcuantImageProcessingWorker.min.js'),
          )
        end

        it 'renders a WASM asset' do
          get "/#{locale}/verify/doc_auth/AcuantImageProcessingWorker.wasm"

          expect(response.status).to eq(200)
          expect(response.headers['Content-Type']).to eq('application/wasm')
          expect(response.body.length).to eq(
            File.size('public/acuant/11.4.1/AcuantImageProcessingWorker.wasm'),
          )
        end

        it 'does not add CSP headers' do
          get "/#{locale}/verify/doc_auth/AcuantImageProcessingWorker.min.js"

          expect(response.headers['Content-Security-Policy']).to be_nil
        end

        it 'does not include session or cookies' do
          get "/#{locale}/verify/doc_auth/AcuantImageProcessingWorker.wasm"
          expect(response.cookies.keys).to_not include('_upaya_session')
        end
      end
    end
  end

  context 'with something that is not a valid Acuant SDK asset' do
    it 'renders a 404' do
      get '/verify/doc_auth/uselss-noise.min.js'

      expect(response.status).to eq(404)
    end

    it 'renders a 404 for map files' do
      get '/verify/doc_auth/AcuantImageProcessingService.wasm.map'

      expect(response.status).to eq(404)
    end
  end
end
