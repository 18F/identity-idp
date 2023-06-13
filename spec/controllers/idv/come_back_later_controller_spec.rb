require 'rails_helper'

RSpec.describe Idv::ComeBackLaterController do
  let(:user) { build_stubbed(:user, :fully_registered) }
  let(:gpo_verification_pending_profile) { true }

  before do
    allow(user).to receive(:gpo_verification_pending_profile?).
      and_return(gpo_verification_pending_profile)
    stub_sign_in(user)
  end

  context 'user needs USPS address verification' do
    it 'renders the show template' do
      stub_analytics

      expect(@analytics).to receive(:track_event).with(
        'IdV: come back later visited',
        proofing_components: nil,
      )

      get :show

      expect(response).to render_template :show
    end
  end

  context 'user does not need USPS address verification' do
    let(:gpo_verification_pending_profile) { false }

    it 'redirects to the account path' do
      get :show

      expect(response).to redirect_to account_path
    end
  end
end
