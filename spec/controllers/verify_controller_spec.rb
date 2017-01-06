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

  describe '#activated' do
    context 'user has an active profile' do
      it 'allows direct access' do
        profile = create(:profile, :active)

        stub_sign_in(profile.user)

        get :activated

        expect(response).to render_template(:activated)
      end
    end

    context 'user does not have an active profile' do
      it 'does not allow direct access' do
        stub_sign_in

        get :activated

        expect(response).to redirect_to verify_url
      end
    end
  end

  describe '#cancel' do
    context 'user has an active profile' do
      it 'does not allow direct access and redirects to activated url' do
        profile = create(:profile, :active)

        stub_sign_in(profile.user)

        get :cancel

        expect(response).to redirect_to verify_activated_url
      end
    end

    context 'user does not have an active profile' do
      it 'allows direct access' do
        stub_sign_in

        get :cancel

        expect(response).to render_template(:cancel)
      end
    end
  end

  describe '#fail' do
    context 'user has an active profile' do
      it 'does not allow direct access and redirects to activated url' do
        profile = create(:profile, :active)

        stub_sign_in(profile.user)

        get :fail

        expect(response).to redirect_to verify_activated_url
      end
    end

    context 'user does not have an active profile and has not exceeded IdV attempts' do
      it 'does not allow direct access and redirects to the main IdV page' do
        stub_sign_in

        get :fail

        expect(response).to redirect_to verify_url
      end
    end

    context 'user does not have an active profile and has exceeded IdV attempts' do
      it 'allows direct access' do
        profile = create(:profile)
        user = profile.user
        user.update(idv_attempts: 3, idv_attempted_at: Time.zone.now)

        stub_sign_in(user)

        get :fail

        expect(response).to render_template(:fail)
      end
    end
  end

  describe '#retry' do
    context 'user has an active profile' do
      it 'does not allow direct access and redirects to activated url' do
        profile = create(:profile, :active)

        stub_sign_in(profile.user)

        get :retry

        expect(response).to redirect_to verify_activated_url
      end
    end

    context 'user does not have an active profile' do
      it 'allows direct access' do
        stub_sign_in

        get :retry

        expect(response).to render_template(:retry)
      end
    end
  end
end
