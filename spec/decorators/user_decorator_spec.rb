require 'rails_helper'

describe UserDecorator do
  describe '#lockout_time_remaining' do
    it 'returns the difference in seconds between otp drift and second_factor_locked_at' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Devise).to receive(:allowed_otp_drift_seconds).and_return(535)

        expect(user_decorator.lockout_time_remaining).to eq 355
      end
    end
  end

  describe '#lockout_time_remaining_in_words' do
    it 'converts lockout_time_remaining to words representing minutes and seconds left' do
      Timecop.freeze(Time.zone.now) do
        user = build_stubbed(:user, second_factor_locked_at: Time.zone.now - 180)
        user_decorator = UserDecorator.new(user)
        allow(Devise).to receive(:allowed_otp_drift_seconds).and_return(535)

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

  describe '#first_sentence_for_confirmation_email' do
    context 'when user.reset_requested_at is present' do
      it 'lets the user know their account was reset by a tech rep' do
        user = build_stubbed(:user, reset_requested_at: Time.zone.now)
        user_decorator = UserDecorator.new(user)

        expect(user_decorator.first_sentence_for_confirmation_email).
          to eq 'Your Upaya account has been reset by a tech support representative. ' \
                'In order to continue, you must confirm your email address.'
      end
    end

    context 'when user.reset_requested_at is nil and user is confirmed' do
      it 'lets the user know how to finish updating their account' do
        user = build_stubbed(:user, confirmed_at: Time.zone.now)
        user_decorator = UserDecorator.new(user)

        expect(user_decorator.first_sentence_for_confirmation_email).
          to eq 'To finish updating your Upaya Account, you must confirm your email address.'
      end
    end

    context 'when user.reset_requested_at is nil and user is not confirmed' do
      it 'lets the user know how to finish creating their account' do
        user = build_stubbed(:user, confirmed_at: nil)
        user_decorator = UserDecorator.new(user)

        expect(user_decorator.first_sentence_for_confirmation_email).
          to eq 'To finish creating your Upaya Account, you must confirm your email address.'
      end
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
end
