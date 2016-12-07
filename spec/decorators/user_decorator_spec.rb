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

  describe '#may_bypass_2fa?' do
    it 'returns true when the user is omniauthed' do
      user = instance_double(User)
      allow(user).to receive(:two_factor_enabled?).and_return(true)

      user_decorator = UserDecorator.new(user)
      session = { omniauthed: true }

      expect(user_decorator.may_bypass_2fa?(session)).to eq true
    end

    it 'returns false when the user is not omniauthed' do
      user = instance_double(User)
      user_decorator = UserDecorator.new(user)

      expect(user_decorator.may_bypass_2fa?).to eq false
    end
  end

  describe '#active_identity_for' do
    it 'returns Identity matching ServiceProvider' do
      sp = ServiceProvider.new('http://sp.example.com')
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

  describe '#should_acknowledge_recovery_code?' do
    it 'returns true when the user has no recovery code and is not omniauthed' do
      user_decorator = UserDecorator.new(User.new)
      session = { omniauthed: false }

      expect(user_decorator.should_acknowledge_recovery_code?(session)).to eq true
    end

    it 'returns false when the user has a recovery code' do
      user_decorator = UserDecorator.new(User.new(recovery_code: 'foo'))
      session = { omniauthed: false }

      expect(user_decorator.should_acknowledge_recovery_code?(session)).to eq false
    end

    it 'returns false when the user is omniauthed' do
      user_decorator = UserDecorator.new(User.new)
      session = { omniauthed: true }

      expect(user_decorator.should_acknowledge_recovery_code?(session)).to eq false
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
end
