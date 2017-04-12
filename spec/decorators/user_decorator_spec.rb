require 'rails_helper'

describe UserDecorator do
  describe '#lockout_time_remaining' do
    it 'returns the difference in seconds between otp drift and second_factor_locked_at' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Devise).to receive(:direct_otp_valid_for).and_return(535)

        expect(user_decorator.lockout_time_remaining).to eq 355
      end
    end
  end

  describe '#lockout_time_remaining_in_words' do
    it 'converts lockout_time_remaining to words representing minutes and seconds left' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Devise).to receive(:direct_otp_valid_for).and_return(535)

        expect(user_decorator.lockout_time_remaining_in_words).
          to eq '5 minutes and 55 seconds'
      end
    end
  end

  describe '#confirmation_period' do
    it 'returns a precise word version of Devise.confirm_within' do
      allow(Devise).to receive(:confirm_within).and_return(24.hours)
      user = build_stubbed(:user)
      user_decorator = UserDecorator.new(user)

      expect(user_decorator.confirmation_period).to eq '24 hours'
    end
  end

  describe '#confirmation_period_expired_error' do
    it 'returns a localized error message when the confirmation period is expired' do
      user = build_stubbed(:user)
      user_decorator = UserDecorator.new(user)

      expect(user_decorator.confirmation_period_expired_error).
        to eq t('errors.messages.confirmation_period_expired',
                period: user_decorator.confirmation_period)
    end
  end

  describe '#active_identity_for' do
    it 'returns Identity matching ServiceProvider' do
      sp = create(:service_provider, issuer: 'http://sp.example.com')
      user = create(:user)
      user.identities << create(
        :identity,
        service_provider: sp.issuer,
        session_uuid: SecureRandom.uuid
      )

      user_decorator = UserDecorator.new(user)

      expect(user_decorator.active_identity_for(sp)).to eq user.last_identity
    end
  end

  describe '#pending_profile' do
    it 'returns Profile awaiting USPS confirmation' do
      profile = create(:profile, deactivation_reason: :verification_pending)
      user_decorator = UserDecorator.new(profile.user)

      expect(user_decorator.pending_profile).to eq profile
    end
  end

  describe '#should_acknowledge_personal_key?' do
    context 'user has no personal key' do
      context 'service provider with loa1' do
        it 'returns true' do
          user_decorator = UserDecorator.new(User.new)
          session = { sp: { loa3: false } }

          expect(user_decorator.should_acknowledge_personal_key?(session)).to eq true
        end
      end

      context 'no service provider' do
        it 'returns true' do
          user_decorator = UserDecorator.new(User.new)
          session = {}

          expect(user_decorator.should_acknowledge_personal_key?(session)).to eq true
        end
      end

      it 'returns false when the user has a personal key' do
        user_decorator = UserDecorator.new(User.new(personal_key: 'foo'))
        session = {}

        expect(user_decorator.should_acknowledge_personal_key?(session)).to eq false
      end

      it 'returns false if the user is loa3' do
        user_decorator = UserDecorator.new(User.new)
        session = { sp: { loa3: true } }

        expect(user_decorator.should_acknowledge_personal_key?(session)).to eq false
      end
    end
  end

  describe '#recent_events' do
    it 'interleaves identities and events' do
      user_decorator = UserDecorator.new(build(:user))
      identity = create(
        :identity,
        last_authenticated_at: Time.zone.now - 1,
        user: user_decorator.user
      )
      event = create(:event, event_type: :email_changed, user: user_decorator.user)

      expect(user_decorator.recent_events).to eq [event.decorate, identity.decorate]
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

        it { expect(partial).to eq('profile/verified_account_badge') }
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
end
