require 'rails_helper'

describe IdvController do
  describe '#index' do
    it 'tracks page visit' do
      stub_sign_in
      stub_analytics

      expect(@analytics).to receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end

    it 'does not track page visit if profile is active' do
      profile = create(:profile, :active, :verified)

      stub_sign_in(profile.user)
      stub_analytics

      expect(@analytics).to_not receive(:track_event).with(Analytics::IDV_INTRO_VISIT)

      get :index
    end

    it 'redirects to failure page if number of attempts has been exceeded' do
      profile = create(
        :profile,
        user: create(:user, idv_attempts: 3, idv_attempted_at: Time.zone.now)
      )

      stub_sign_in(profile.user)

      get :index

      expect(response).to redirect_to idv_fail_url
    end

    it 'redirects to account recovery if user has a password reset profile' do
      profile = create(:profile, deactivation_reason: :password_reset)
      stub_sign_in(profile.user)
      allow(subject.reactivate_account_session).to receive(:started?).and_return(true)

      get :index

      expect(response).to redirect_to reactivate_account_url
    end
  end

  describe '#activated' do
    context 'user has an active profile' do
      it 'allows direct access' do
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        get :activated

        expect(response).to render_template(:activated)
        expect(subject.idv_session.alive?).to eq false
      end

      it 'resets IdV attempts' do
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        attempter = instance_double(Idv::Attempter, reset: false)
        allow(Idv::Attempter).to receive(:new).with(profile.user).and_return(attempter)

        expect(attempter).to receive(:reset)

        get :activated
      end
    end

    context 'user does not have an active profile' do
      it 'does not allow direct access' do
        stub_sign_in

        get :activated

        expect(response).to redirect_to idv_url
      end
    end
  end

  describe '#cancel' do
    context 'user has an active profile' do
      it 'does not allow direct access and redirects to activated url' do
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        get :cancel

        expect(response).to redirect_to idv_activated_url
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
        profile = create(:profile, :active, :verified)

        stub_sign_in(profile.user)

        get :fail

        expect(response).to redirect_to idv_activated_url
      end
    end

    context 'user does not have an active profile and has not exceeded IdV attempts' do
      it 'does not allow direct access and redirects to the main IdV page' do
        stub_sign_in

        get :fail

        expect(response).to redirect_to idv_url
      end
    end

    context 'user does not have an active profile and has exceeded IdV attempts' do
      it 'allows direct access' do
        profile = create(
          :profile,
          user: create(:user, idv_attempts: 3, idv_attempted_at: Time.zone.now)
        )

        stub_sign_in(profile.user)

        get :fail

        expect(response).to render_template(:fail)
      end
    end
  end
end
