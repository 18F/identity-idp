require 'rails_helper'

describe 'requesting acuant SDK assets' do
  # example URLs:
  # - /verify/doc_auth/AcuantImageProcessingWorker.min.js
  # - /en/verify/capture_doc/AcuantImageProcessingWorker.min.js
  [nil, *I18n.available_locales].
    product(%w[doc_auth capture_doc]).
    each do |locale, verify_path|
      base_url = "#{locale && "/#{locale}"}/verify/#{verify_path}"
      context "base url #{base_url}" do
        context 'with a valid Acuant SDK asset' do
          it 'renders a JS asset, without CSP headers, without a session' do
            get "#{base_url}/AcuantImageProcessingWorker.min.js"

            expect(response.status).to eq(200)
            expect(response.headers['Content-Type']).to eq('application/javascript')
            expect(response.headers).to_not have_key('Content-Security-Policy')
            expect(response.cookies.keys).to_not include('_upaya_session')
            expect(response.body).to eq(
              File.read('public/acuant/11.4.1/AcuantImageProcessingWorker.min.js'),
            )
          end

          it 'renders a WASM asset without CSP headers, without a session' do
            get "#{base_url}/AcuantImageProcessingWorker.wasm"

            expect(response.status).to eq(200)
            expect(response.headers['Content-Type']).to eq('application/wasm')
            expect(response.headers).to_not have_key('Content-Security-Policy')
            expect(response.cookies.keys).to_not include('_upaya_session')
            expect(response.body.length).to eq(
              File.size('public/acuant/11.4.1/AcuantImageProcessingWorker.wasm'),
            )
          end
        end

        context 'with something that is not a valid Acuant SDK asset' do
          it 'renders a 404 and leaves in the CSP headers' do
            get "#{base_url}/something-that-does-not-exist/AcuantImageProcessingWorker.wasm"

            expect(response.status).to eq(404)
            expect(response.headers['Content-Security-Policy']).to be_present
          end

          it 'renders a 404 for map files' do
            get "#{base_url}/AcuantImageProcessingService.wasm.map"

            expect(response.status).to eq(404)
          end
        end
      end
    end
end
