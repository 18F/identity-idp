require 'rails_helper'

describe Idv::UnavailableController, type: :controller do
  let(:idv_available) { false }

  before do
    allow(IdentityConfig.store).to receive(:idv_available).and_return(idv_available)
  end

  describe '#show' do
    before do
      stub_analytics
      get :show
    end

    it 'returns 503 Service Unavailable status' do
      # https://http.cat/503
      expect(response.status).to eql(503)
    end

    it 'logs an analytics event' do
      expect(@analytics).to have_logged_event(
        'Vendor Outage',
        redirect_from: nil,
        vendor_status: {
          acuant: :operational,
          lexisnexis_instant_verify: :operational,
          lexisnexis_trueid: :operational,
          sms: :operational,
          voice: :operational,
        },
      )
    end

    it 'renders the view' do
      expect(response).to render_template('idv/unavailable')
    end

    context 'IdV is enabled' do
      let(:idv_available) { true }

      it 'redirects back to account page' do
        get :show
        expect(response).to redirect_to(account_path)
      end

      context 'coming from registration page' do
        it 'redirects back to registration' do
          get :show, params: { from: 'registration' }
          expect(response).to redirect_to(sign_up_email_path)
        end
      end
    end
  end
end
