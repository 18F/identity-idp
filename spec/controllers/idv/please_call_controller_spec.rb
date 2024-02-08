require 'rails_helper'

RSpec.describe Idv::PleaseCallController do
  let(:user) { create(:user) }
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enforce_tmx) { false }
  let(:fraud_review_pending_date) { profile.fraud_review_pending_at }
  let(:verify_date) { profile.verified_at }
  let!(:profile) { create(:profile, :verified, :fraud_review_pending, user: user) }

  before do
    stub_sign_in(user)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
      and_return(in_person_proofing_enforce_tmx)
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

  context 'in person proofing and tmx enabled' do
    let(:in_person_proofing_enabled) { true }
    let(:in_person_proofing_enforce_tmx) { true }
    let!(:enrollment) { create(:in_person_enrollment, :passed, user: user, profile: profile) }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
        and_return(in_person_proofing_enabled)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
        and_return(in_person_proofing_enforce_tmx)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    it 'returns true from ipp_enabled_and_enrollment_passed' do
      expect(subject.ipp_enabled_and_enrollment_passed?).to eq(true)
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

    context 'in person proofing and tmx disabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_proofing_enforce_tmx) { false }
      let!(:enrollment) { create(:in_person_enrollment, :passed, user: user, profile: profile) }

      before do
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
          and_return(in_person_proofing_enabled)
        allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx).
          and_return(in_person_proofing_enforce_tmx)
      end

      it 'renders the show template' do
        get :show

        expect(response).to render_template :show
      end

      it 'returns false from ipp_enabled_and_enrollment_passed' do
        expect(subject.ipp_enabled_and_enrollment_passed?).to eq(nil)
      end
    end
  end
end
