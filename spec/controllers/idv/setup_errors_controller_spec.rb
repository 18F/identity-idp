require 'rails_helper'

describe Idv::SetupErrorsController do
  let(:user) { create(:user) }
  let(:verify_date) { 20.days.ago }

  before do
    create(:profile, fraud_review_pending: true, verified_at: verify_date, user: user)

    stub_sign_in(user)
  end

  it 'renders the show template' do
    stub_analytics

    expect(@analytics).to receive(:track_event).with(
      'IdV: Verify setup errors visited',
      proofing_components: nil,
    )

    get :show

    expect(response).to render_template :show
  end

  render_views

  it 'asks user to call 2 weeks from verified_at date' do
    get :show

    two_weeks = (verify_date + 14.days).to_s
    two_weeks_formatted = I18n.l(Date.parse(two_weeks), format: I18n.t('time.formats.event_date'))
    expect(response.body).to include(two_weeks_formatted)
  end
end
