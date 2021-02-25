require 'rails_helper'

describe 'frontend analytics requests' do
  describe 'platform authenticators' do
    let(:analytics) { FakeAnalytics.new }

    before do
      allow(analytics).to receive(:track_event)
      allow(Analytics).to receive(:new).and_return(analytics)
    end

    it 'does not log anything if the user is not authed' do
      expect(analytics).to_not receive(:track_event).
        with(Analytics::FRONTEND_BROWSER_CAPABILITIES, any_args)

      post analytics_path, params: { platform_authenticator: { available: true } }
    end

    it 'logs true if the platform authenticator is available' do
      sign_in_user

      post analytics_path, params: { platform_authenticator: { available: true } }

      expect(analytics).to have_received(:track_event).
        with(Analytics::FRONTEND_BROWSER_CAPABILITIES, hash_including(platform_authenticator: true))
    end

    it 'logs false if the platform authenticator is not available' do
      sign_in_user

      post analytics_path, params: { platform_authenticator: { available: false } }

      expect(analytics).to have_received(:track_event).
        with(
          Analytics::FRONTEND_BROWSER_CAPABILITIES,
          hash_including(platform_authenticator: false),
        )
    end

    it 'only logs 1 platform authenticator event per session' do
      sign_in_user

      post analytics_path, params: { platform_authenticator: { available: true } }
      post analytics_path, params: { platform_authenticator: { available: true } }

      expect(analytics).to have_received(:track_event).
        with(
          Analytics::FRONTEND_BROWSER_CAPABILITIES,
          hash_including(platform_authenticator: true),
        ).
        once
    end

    it 'logs ignores garbage values' do
      sign_in_user

      post analytics_path, params: { platform_authenticator: { available: 'blah blah blah' } }

      expect(analytics).to_not have_received(:track_event).
        with(Analytics::FRONTEND_BROWSER_CAPABILITIES, any_args)
    end
  end
end
