require 'rails_helper'

describe VendorOutageController do
  before do
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  let(:redirect_from) { nil }
  let(:tracking_data) do
    {
      vendor_status: {
        acuant: IdentityConfig.store.vendor_status_acuant,
        lexisnexis_instant_verify: IdentityConfig.store.vendor_status_lexisnexis_instant_verify,
        lexisnexis_trueid: IdentityConfig.store.vendor_status_lexisnexis_trueid,
      },
      redirect_from: redirect_from,
    }
  end

  it 'tracks an analytics event' do
    get :show

    expect(@analytics).to have_received(:track_event).with(
      Analytics::VENDOR_OUTAGE,
      tracking_data,
    )
  end
end
