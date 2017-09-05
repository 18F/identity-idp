require 'rails_helper'

describe Idv::UspsMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::UspsMail.new(user) }

  describe '#mail_spammed?' do
    context 'when no mail has been sent' do
      it 'returns false' do
        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when the amount of sent mail is lower than the allowed maximum' do
      it 'returns false' do
        Event.create(event_type: :usps_mail_sent, user: user)

        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when too much mail has been sent' do
      it 'returns true if the oldest event was within the last month' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 2.weeks.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.week.ago)

        expect(subject.mail_spammed?).to eq true
      end

      it 'returns false if the oldest event was more than a month ago' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 2.weeks.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 2.months.ago)

        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when MAX_MAIL_EVENTS or MAIL_EVENTS_WINDOW_DAYS are zero' do
      it 'returns false' do
        stub_const 'Idv::UspsMail::MAX_MAIL_EVENTS', 0
        stub_const 'Idv::UspsMail::MAIL_EVENTS_WINDOW_DAYS', 0

        expect(subject.mail_spammed?).to eq false
      end
    end
  end

  describe '#most_recent_otp_expired?' do
    context 'when no mail has been sent' do
      it 'returns false' do
        expect(subject.most_recent_otp_expired?).to eq false
      end
    end

    context 'when the most recent mail was sent less than 10 days ago' do
      it 'returns false' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 5.days.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 12.days.ago)

        expect(subject.most_recent_otp_expired?).to eq false
      end
    end

    context 'when the most recent mail was sent more than 10 days ago' do
      it 'returns true' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 11.days.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 12.days.ago)

        expect(subject.most_recent_otp_expired?).to eq true
      end
    end
  end
end
