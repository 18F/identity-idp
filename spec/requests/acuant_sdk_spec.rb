require 'rails_helper'

describe 'requesting acuant SDK assets' do
  # example URLs:
  # - /verify/doc_auth/AcuantImageProcessingWorker.min.js
  # - /en/verify/capture_doc/AcuantImageProcessingWorker.min.js
  [nil, *I18n.available_locales].
    product(%w[doc_auth capture_doc]).
    each do |locale, verify_path|
      base_url = "#{locale && "/#{locale}"}/verify/#{verify_path}"

      min_js = "#{base_url}/AcuantImageProcessingWorker.min.js"
      context min_js do
        before { get min_js }

        it 'renders a JS asset' do
          expect(response.status).to eq(200)
          expect(response.headers['Content-Type']).to eq('application/javascript')
          expect(response.body).to eq(
            File.read('public/acuant/11.4.3/AcuantImageProcessingWorker.min.js'),
          )
        end

        it 'does not include a CSP header' do
          expect(response.headers).to_not have_key('Content-Security-Policy')
        end

        it 'does not include a session' do
          expect(response.cookies.keys).to_not include('_upaya_session')
        end
      end

      wasm_js = "#{base_url}/AcuantImageProcessingWorker.wasm"
      context wasm_js do
        before { get wasm_js }

        it 'renders a WASM asset' do
          expect(response.status).to eq(200)
          expect(response.headers['Content-Type']).to eq('application/wasm')
          expect(response.body.length).to eq(
            File.size('public/acuant/11.4.3/AcuantImageProcessingWorker.wasm'),
          )
        end

        it 'includes a CSP header with unsafe-eval' do
          expect(response.headers['Content-Security-Policy']).
            to match(/script-src [^;]*'unsafe-eval'/)
        end

        it 'does not include a session' do
          expect(response.cookies.keys).to_not include('_upaya_session')
        end
      end

      invalid_asset = "#{base_url}/something-that-does-not-exist/AcuantImageProcessingWorker.wasm"
      context "#{invalid_asset} (invalid asset)" do
        before { get invalid_asset }

        it 'renders a 404 and leaves in the CSP headers' do
          expect(response.status).to eq(404)
          expect(response.headers['Content-Security-Policy']).to be_present
        end
      end

      map_file = "#{base_url}/AcuantImageProcessingService.wasm.map"
      context "#{map_file} (map file)" do
        before { get map_file }

        it 'renders a 404 and leaves in the CSP headers' do
          expect(response.status).to eq(404)
          expect(response.headers['Content-Security-Policy']).to be_present
        end
      end
    end
end
