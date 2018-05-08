require 'rails_helper'

describe Idv::ComeBackLaterController do
  let(:user) { build_stubbed(:user, :signed_up) }
  let(:needs_profile_usps_verification) { true }

  before do
    user_decorator = instance_double(UserDecorator)
    allow(user_decorator).to receive(:needs_profile_usps_verification?).
      and_return(needs_profile_usps_verification)
    allow(user).to receive(:decorate).and_return(user_decorator)
    allow(subject).to receive(:current_user).and_return(user)
  end

  context 'user needs USPS address verification' do
    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end
  end

  context 'user does not need USPS address verification' do
    let(:needs_profile_usps_verification) { false }

    it 'redirects to the account path' do
      get :show

      expect(response).to redirect_to account_path
    end
  end
end
