require 'rails_helper'

describe 'requesting acuant SDK assets' do
  version = Pathname.new(Dir[Rails.root.join('public/acuant/*')].first).basename.to_s
  base_url = "/acuant/#{version}"

  min_js = "#{base_url}/AcuantImageWorker.min.js"
  context min_js do
    before { get min_js }

    it 'renders a JS asset' do
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/javascript')
    end

    it 'does not include a CSP header' do
      expect(response.headers).to_not have_key('Content-Security-Policy')
    end

    it 'does not include a session' do
      expect(response.cookies.keys).to_not include('_identity_idp_session')
    end
  end

  wasm_js = "#{base_url}/AcuantImageService.wasm"
  context wasm_js do
    before { get wasm_js }

    it 'renders a WASM asset' do
      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to eq('application/wasm')
    end

    it 'does not include a session' do
      expect(response.cookies.keys).to_not include('_identity_idp_session')
    end
  end

  invalid_asset = "#{base_url}/something-that-does-not-exist/AcuantImageService.wasm"
  context "#{invalid_asset} (invalid asset)" do
    before { get invalid_asset }

    it 'renders a 404 and leaves in the CSP headers' do
      expect(response.status).to eq(404)
      expect(response.headers['Content-Security-Policy']).to be_present
    end
  end
end
