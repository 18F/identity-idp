require 'rails_helper'

describe SendExpiredLetterNotifications do
  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

  describe '#call' do
    context 'after the letters expire' do
      it 'does not send notifications when the notifications were already sent' do
        usps_confirmation_code = create_ucc_for(profile)
        usps_confirmation_code.letter_expired_sent_at = Time.zone.now
        usps_confirmation_code.save

        after_the_letters_expire do
          SendExpiredLetterNotifications.new.call
          notifications_sent = SendExpiredLetterNotifications.new.call
          expect(notifications_sent).to eq(0)
        end
      end

      it 'does not send notifications when the letters bounced' do
        usps_confirmation_code = create_ucc_for(profile)
        usps_confirmation_code.bounced_at = Time.zone.now
        usps_confirmation_code.save

        after_the_letters_expire do
          notifications_sent = SendExpiredLetterNotifications.new.call
          expect(notifications_sent).to eq(0)
        end
      end

      it 'sends notifications if not bounced and not already sent' do
        create_ucc_for(profile)

        after_the_letters_expire do
          notifications_sent = SendExpiredLetterNotifications.new.call

          expect(notifications_sent).to eq(1)
        end
      end
    end

    context 'when the letters are not expired' do
      it 'does not send notifications' do
        create_ucc_for(profile)

        notifications_sent = SendExpiredLetterNotifications.new.call
        expect(notifications_sent).to eq(0)
      end
    end
  end

  def create_ucc_for(profile)
    UspsConfirmationCode.create(
      profile: profile,
      otp_fingerprint: 'foo',
    )
  end

  def after_the_letters_expire
    days = Figaro.env.usps_confirmation_max_days.to_i.days
    Timecop.travel(Time.zone.now + days) do
      yield
    end
  end
end
