require 'rails_helper'

RSpec.describe Idv::ByMail::EnterCodeRateLimitedController do
  # let(:user) { build_stubbed(:user, :fully_registered) }
  let(:user) { build_stubbed(:user, :with_pending_gpo_profile) }
  let(:pending_profile) do
    if user
      create(:profile, :verify_by_mail_pending, user:)
    end
  end
  let(:has_pending_profile) { true }

  before do
    stub_sign_in(user)
    stub_user_with_pending_profile(user)
    stub_analytics
    stub_attempts_tracker
    RateLimiter.new(rate_limit_type: :verify_gpo_key, user:).increment_to_limited!
  end

  describe '#index' do
    it 'renders the rate limited page' do
      expect(@analytics).to receive(:track_event).with(
        'Rate Limit Reached',
        limiter_type: :verify_gpo_key,
      ).once

      expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_rate_limited).once

      get :index

      expect(response).to render_template :index
    end
  end
end
