require 'rails_helper'

describe Idv::OutageController do
  before do
    stub_analytics
  end

  describe '#show' do
    before do
      get :show
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
      expect(response).to render_template('idv/outage/show')
    end
  end
end
