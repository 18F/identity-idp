require 'rails_helper'

describe Idv::ComeBackLaterController do
  let(:user) { build_stubbed(:user, :fully_registered) }
  let(:pending_profile_requires_verification) { true }

  before do
    allow(user).to receive(:pending_profile_requires_verification?).
      and_return(pending_profile_requires_verification)
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
    let(:pending_profile_requires_verification) { false }

    it 'redirects to the account path' do
      get :show

      expect(response).to redirect_to account_path
    end
  end
end
