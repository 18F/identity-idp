require 'rails_helper'

describe VerifyController do
  describe '#index' do
    it 'tracks page visit' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end

    it 'does not track page visit if profile is active' do
      profile = create(:profile, :active)

      stub_sign_in(profile.user)
      stub_analytics

      expect(@analytics).to_not receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end
  end
end
