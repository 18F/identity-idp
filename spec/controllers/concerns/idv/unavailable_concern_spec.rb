require 'rails_helper'

describe Idv::UnavailableConcern, type: :controller do
  controller ApplicationController do
    include Idv::UnavailableConcern
    def index
      render_idv_unavailable
    end
  end

  describe '#render_idv_unavailable' do
    before do
      stub_analytics
      get :index
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
  end
end
