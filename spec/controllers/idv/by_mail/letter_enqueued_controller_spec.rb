require 'rails_helper'

RSpec.describe Idv::ByMail::LetterEnqueuedController do
  let(:user) { build_stubbed(:user, :fully_registered) }
  let(:gpo_verification_pending_profile) { true }

  before do
    allow(user).to receive(:gpo_verification_pending_profile?)
      .and_return(gpo_verification_pending_profile)
    stub_sign_in(user)
  end

  context 'user needs USPS address verification' do
    it 'logs an analytics event' do
      stub_analytics

      get :show

      expect(@analytics).to have_logged_event('IdV: letter enqueued visited')
    end

    it 'renders the show template' do
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
