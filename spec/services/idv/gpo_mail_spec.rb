require 'rails_helper'

describe Idv::GpoMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::GpoMail.new(user) }

  describe '#mail_spammed?' do
    context 'when no mail has been sent' do
      it 'returns false' do
        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when the amount of sent mail is lower than the allowed maximum' do
      it 'returns false' do
        event_create(event_type: :gpo_mail_sent, user: user)

        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when too much mail has been sent' do
      it 'returns true if the oldest event was within the last month' do
        event_create(event_type: :gpo_mail_sent, user: user, updated_at: 2.weeks.ago)
        event_create(event_type: :gpo_mail_sent, user: user, updated_at: 1.week.ago)

        expect(subject.mail_spammed?).to eq true
      end

      it 'returns false if the oldest event was more than a month ago' do
        event_create(event_type: :gpo_mail_sent, user: user, updated_at: 2.weeks.ago)
        event_create(event_type: :gpo_mail_sent, user: user, updated_at: 2.months.ago)

        expect(subject.mail_spammed?).to eq false
      end
    end

    context 'when MAX_MAIL_EVENTS or MAIL_EVENTS_WINDOW_DAYS are zero' do
      it 'returns false' do
        stub_const 'Idv::GpoMail::MAX_MAIL_EVENTS', 0
        stub_const 'Idv::GpoMail::MAIL_EVENTS_WINDOW_DAYS', 0

        expect(subject.mail_spammed?).to eq false
      end
    end
  end

  def event_create(hash)
    uuid = 'foo'
    remote_ip = '127.0.0.1'
    user = hash[:user]
    event = hash[:event_type]
    now = Time.zone.now
    updated_at = hash[:updated_at] || now
    device = Device.find_by(user_id: user.id, cookie_uuid: uuid)
    if device
      device.last_used_at = now
      device.last_ip = remote_ip
      device.save
    else
      last_login_at = Time.zone.now
      device = Device.create(
        user_id: user.id,
        user_agent: '',
        cookie_uuid: uuid,
        last_used_at: last_login_at,
        last_ip: remote_ip,
      )
    end
    Event.create(
      user_id: user.id,
      device_id: device.id,
      ip: remote_ip,
      event_type: event,
      created_at: updated_at,
      updated_at: updated_at,
    )
  end
end
