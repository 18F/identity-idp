require 'rails_helper'

describe Verify::ComeBackLaterController do
  let(:user) { build_stubbed(:user, :signed_up) }
  let(:address_verification_mechanism) { 'usps' }
  let(:profile) { build_stubbed(:profile, user: user) }
  let(:idv_session) do
    Idv::Session.new(
      user_session: { context: :idv },
      current_user: user,
      issuer: nil
    )
  end

  before do
    allow(idv_session).to receive(:address_verification_mechanism).
      and_return(address_verification_mechanism)
    allow(idv_session).to receive(:profile).
      and_return(profile)
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  context 'user has selected USPS address verification and has a complete profile' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end
  end

  context 'user has not selected USPS address verification' do
    let(:address_verification_mechanism) { 'phone' }

    it 'redirects to the account path' do
      get :show

      expect(response).to redirect_to account_path
    end
  end

  context 'does not have a complete profile' do
    let(:profile) { nil }

    it 'redirects to the account path' do
      get :show

      expect(response).to redirect_to account_path
    end
  end
end
