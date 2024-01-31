require 'rails_helper'

RSpec.describe Idv::PleaseCallController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, service_provider: nil)
  end
  let(:fraud_review_pending_date) { profile.fraud_review_pending_at }
  let(:verify_date) { profile.verified_at }
  let!(:profile) { create(:profile, :verified, :fraud_review_pending, user: user) }

  before do
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
  end

  render_views

  it 'redirects a user who is not fraud review pending' do
    profile.activate_after_fraud_review_unnecessary

    get :show

    expect(response).to redirect_to(account_url)
  end

  it 'redirects a user who has been fraud rejected' do
    profile.reject_for_fraud(notify_user: false)

    get :show

    expect(response).to redirect_to(idv_not_verified_url)
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

  it 'asks user to call 2 weeks from fraud_review_pending_date' do
    get :show

    call_by_date = fraud_review_pending_date + 14.days
    call_by_formatted = I18n.l(call_by_date, format: :event_date)
    expect(response.body).to include(call_by_formatted)
  end

  context 'in person proofing enabled enforce tmx true' do
    let(:in_person_proofing_enabled) { true }
    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
        and_return(in_person_proofing_enabled)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      allow(idv_session).to receive(:idv).and_return({ flow_path: 'standard' })
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'redirects a user who is not fraud review pending' do
      profile.activate_after_fraud_review_unnecessary

      get :show

      expect(response).to redirect_to(account_url)
    end

    it 'redirects a user who has been fraud rejected' do
      profile.reject_for_fraud(notify_user: false)

      get :show

      expect(response).to redirect_to(idv_not_verified_url)
    end

    context 'flow path is hybrid' do
      before do
        allow(idv_session).to receive(:idv).and_return({ flow_path: 'hybrid' })
      end
      # the change expected here is in the view not the controller
      it 'shows the page if flow path is not standard' do
        get :show

        expect(response).to render_template :show
      end
    end
  end
end
