require 'rails_helper'

describe Idv::UspsMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::UspsMail.new(user) }

  describe '#mail_spammed?' do
    context 'when no mail has been sent' do
      it 'is never spammed' do
        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when too much mail has been sent' do
      it 'is spammed if all the updates have been within the last month' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 2.weeks.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.week.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.day.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.hour.ago)

        expect(subject.mail_spammed?).to eq true
      end

      it 'is not spammed if the most distant update was more than a month ago' do
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 2.months.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.week.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.day.ago)
        Event.create(event_type: :usps_mail_sent, user: user, updated_at: 1.hour.ago)

        expect(subject.mail_spammed?).to eq false
      end
    end
  end
end
