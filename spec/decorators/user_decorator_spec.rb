require 'rails_helper'

describe UserDecorator do
  describe '#lockout_time_remaining' do
    it 'returns the difference in seconds between otp drift and second_factor_locked_at' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Figaro.env).to receive(:lockout_period_in_minutes).and_return('8')

        expect(user_decorator.lockout_time_remaining).to eq 300
      end
    end
  end

  describe '#lockout_time_remaining_in_words' do
    it 'converts lockout_time_remaining to words representing minutes and seconds left' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Figaro.env).to receive(:lockout_period_in_minutes).and_return('8')

        expect(user_decorator.lockout_time_remaining_in_words).
          to eq '5 minutes'
      end
    end
  end

  describe '#masked_number' do
    it 'returns blank for a nil number' do
      user = build_stubbed(:user)
      user_decorator = UserDecorator.new(user)
      expect(user_decorator.send(:masked_number, nil)).to eq ''
    end
  end

  describe '#active_identity_for' do
    it 'returns Identity matching ServiceProvider' do
      sp = create(:service_provider, issuer: 'http://sp.example.com')
      user = create(:user)
      user.identities << create(
        :identity,
        service_provider: sp.issuer,
        session_uuid: SecureRandom.uuid,
      )

      user_decorator = UserDecorator.new(user)

      expect(user_decorator.active_identity_for(sp)).to eq user.last_identity
    end
  end

  describe '#pending_profile_requires_verification?' do
    it 'returns false when no pending profile exists' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return(nil)

      expect(user_decorator.pending_profile_requires_verification?).to eq false
    end

    it 'returns true when pending profile exists and identity is not verified' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(true)

      expect(user_decorator.pending_profile_requires_verification?).to eq true
    end

    it 'returns false when active profile is newer than pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(false)
      allow(user_decorator).to receive(:active_profile_newer_than_pending_profile?).
        and_return(true)

      expect(user_decorator.pending_profile_requires_verification?).to eq false
    end

    it 'returns true when pending profile is newer than active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:pending_profile).and_return('profile')
      allow(user_decorator).to receive(:identity_not_verified?).and_return(false)
      allow(user_decorator).to receive(:active_profile_newer_than_pending_profile?).
        and_return(false)

      expect(user_decorator.pending_profile_requires_verification?).to eq true
    end
  end

  describe '#pending_profile' do
    context 'when a profile with a verification_pending deactivation_reason exists' do
      it 'returns the most recent profile' do
        user = User.new
        _old_profile = create(
          :profile,
          deactivation_reason: :verification_pending,
          created_at: 1.day.ago,
          user: user,
        )
        new_profile = create(
          :profile,
          deactivation_reason: :verification_pending,
          user: user,
        )
        user_decorator = UserDecorator.new(user)

        expect(user_decorator.pending_profile).to eq new_profile
      end
    end

    context 'when a verification_pending profile does not exist' do
      it 'returns nil' do
        user = User.new
        create(
          :profile,
          deactivation_reason: :password_reset,
          created_at: 1.day.ago,
          user: user,
        )
        create(
          :profile,
          deactivation_reason: :encryption_error,
          user: user,
        )
        user_decorator = UserDecorator.new(user)

        expect(user_decorator.pending_profile).to be_nil
      end
    end
  end

  describe '#identity_not_verified?' do
    it 'returns true if identity_verified returns false' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:identity_verified?).and_return(false)

      expect(user_decorator.identity_not_verified?).to eq true
    end

    it 'returns false if identity_verified returns true' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user_decorator).to receive(:identity_verified?).and_return(true)

      expect(user_decorator.identity_not_verified?).to eq false
    end
  end

  describe '#identity_verified?' do
    it 'returns true if user has an active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new)

      expect(user_decorator.identity_verified?).to eq true
    end

    it 'returns false if user does not have an active profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(nil)

      expect(user_decorator.identity_verified?).to eq false
    end
  end

  describe '#active_profile_newer_than_pending_profile?' do
    it 'returns true if the active profile is newer than the pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: Time.zone.now))
      allow(user_decorator).to receive(:pending_profile).
        and_return(Profile.new(created_at: 1.day.ago))

      expect(user_decorator.active_profile_newer_than_pending_profile?).to eq true
    end

    it 'returns false if the active profile is older than the pending profile' do
      user = User.new
      user_decorator = UserDecorator.new(user)
      allow(user).to receive(:active_profile).and_return(Profile.new(activated_at: 1.day.ago))
      allow(user_decorator).to receive(:pending_profile).
        and_return(Profile.new(created_at: Time.zone.now))

      expect(user_decorator.active_profile_newer_than_pending_profile?).to eq false
    end
  end

  describe '#recent_events' do
    let!(:user) { create(:user, :signed_up, created_at: Time.zone.now - 100.days) }
    let(:decorated_user) { user.decorate }
    let!(:event) { create(:event, user: user, created_at: Time.zone.now - 98.days) }
    let!(:identity) do
      create(:identity, :active, user: user, last_authenticated_at: Time.zone.now - 60.days)
    end
    let!(:another_event) do
      create(:event, user: user, event_type: :email_changed, created_at: Time.zone.now - 30.days)
    end

    it 'interleaves identities and events, decorates them, and sorts them in descending order' do
      expect(decorated_user.recent_events).
        to eq [another_event.decorate, identity.decorate, event.decorate]
    end
  end

  context 'badge partials' do
    let(:verified_profile) do
      build(:profile, :active, :verified, pii: { ssn: '1111', dob: '1920-01-01' })
    end

    describe '#verified_account_partial' do
      subject(:partial) { UserDecorator.new(user).verified_account_partial }

      context 'with an unverified account' do
        let(:user) { build(:user) }

        it { expect(partial).to eq('shared/null') }
      end

      context 'with a verified account' do
        let(:user) { create(:user, profiles: [verified_profile]) }

        it { expect(partial).to eq('accounts/verified_account_badge') }
      end
    end
  end

  describe '#password_reset_profile' do
    let(:user) { create(:user) }
    subject(:decorated_user) { UserDecorator.new(user) }

    context 'with no profiles' do
      it { expect(decorated_user.password_reset_profile).to be_nil }
    end

    context 'with an active profile' do
      let(:active_profile) do
        build(:profile, :active, :verified, activated_at: 1.day.ago, pii: { first_name: 'Jane' })
      end

      before do
        user.profiles << [
          active_profile,
          build(:profile, :verified, activated_at: 5.days.ago, pii: { first_name: 'Susan' }),
        ]
      end

      it { expect(decorated_user.password_reset_profile).to be_nil }

      context 'when the active profile is deactivated due to password reset' do
        before { active_profile.deactivate(:password_reset) }

        it { expect(decorated_user.password_reset_profile).to eq(active_profile) }
      end
    end
  end

  describe '#delete_account_bullet_key' do
    let(:user_decorator) { UserDecorator.new(build_stubbed(:user)) }

    it 'returns loa1 if identity is not verified' do
      allow(user_decorator).to receive(:identity_verified?).and_return(false)
      expect(user_decorator.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_loa1', app: APP_NAME)
    end

    it 'returns loa3 if identity is verified' do
      allow(user_decorator).to receive(:identity_verified?).and_return(true)
      expect(user_decorator.delete_account_bullet_key).
        to eq t('users.delete.bullet_2_loa3', app: APP_NAME)
    end
  end
end
