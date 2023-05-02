require 'rails_helper'

describe Idv::PleaseCallController do
  let(:user) { create(:user) }
  let(:verify_date) { 20.days.ago }

  before do
    user.profiles.create(
      fraud_review_pending_at: 1.day.ago,
      verified_at: verify_date,
    )

    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    expect(@analytics).to receive(:track_event).with(
      'IdV: Verify please call visited',
      proofing_components: nil,
    )

    get :show

    expect(response).to render_template :show
  end

  render_views

  it 'asks user to call 2 weeks from verified_at date' do
    get :show

    call_by_date = verify_date + 14.days
    call_by_formatted = I18n.l(call_by_date, format: :event_date)
    expect(response.body).to include(call_by_formatted)
  end
end
