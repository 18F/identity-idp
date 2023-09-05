require 'rails_helper'

RSpec.describe Idv::GpoMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::GpoMail.new(user) }
  let(:max_mail_events) { 2 }
  let(:mail_events_window_days) { 30 }
  let(:minimum_wait_before_another_usps_letter_in_hours) { 24 }

  before do
    stub_const 'Idv::GpoMail::MAX_MAIL_EVENTS', max_mail_events
    stub_const 'Idv::GpoMail::MAIL_EVENTS_WINDOW_DAYS', mail_events_window_days
    stub_const 'Idv::GpoMail::MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER_IN_HOURS',
               minimum_wait_before_another_usps_letter_in_hours
  end

  describe '#mail_spammed?' do
    context 'when no mail has been sent' do
      it 'returns false' do
        expect(subject.mail_spammed?).to be_falsey
      end
    end

    context 'when the amount of sent mail is lower than the allowed maximum' do
      context 'and the most recent mail event is too recent' do
        it 'returns true' do
          enqueue_gpo_letter_for(user)

          expect(subject.mail_spammed?).to eq true
        end
      end

      context 'and the most recent email is not too recent' do
        it 'returns false' do
          enqueue_gpo_letter_for(user, at: 25.hours.ago)

          expect(subject.mail_spammed?).to be_falsey
        end
      end
    end

    context 'when too much mail has been sent' do
      it 'returns true if the oldest mail was within the mail events window' do
        enqueue_gpo_letter_for(user, at: 2.weeks.ago)
        enqueue_gpo_letter_for(user, at: 1.week.ago)

        expect(subject.mail_spammed?).to eq true
      end

      it 'returns false if the oldest mail was outside the mail events window' do
        enqueue_gpo_letter_for(user, at: 2.weeks.ago)
        enqueue_gpo_letter_for(user, at: 2.months.ago)

        expect(subject.mail_spammed?).to be_falsey
      end
    end

    context 'when we would normally be rate limited' do
      before do
        enqueue_gpo_letter_for(user, at: 2.days.ago)
        enqueue_gpo_letter_for(user)
      end

      context 'but MAX_MAIL_EVENTS is zero' do
        let(:max_mail_events) { 0 }

        context 'and MAIL_EVENTS_WINDOW is zero' do
          let(:mail_events_window_days) { 0 }

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is zero' do
            let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

            it 'returns false' do
              expect(subject.mail_spammed?).to be_falsey
            end
          end

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is non-zero' do
            it 'returns true' do
              expect(subject.mail_spammed?).to eq true
            end
          end
        end

        context 'and MAIL_EVENTS_WINDOW is non-zero' do
          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is zero' do
            let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

            it 'returns false' do
              expect(subject.mail_spammed?).to be_falsey
            end
          end

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is non-zero' do
            it 'returns true' do
              expect(subject.mail_spammed?).to eq true
            end
          end
        end
      end

      context 'but MAX_MAIL_EVENTS is non-zero' do
        context 'and MAIL_EVENTS_WINDOW is zero' do
          let(:mail_events_window_days) { 0 }

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is zero' do
            let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

            it 'returns false' do
              expect(subject.mail_spammed?).to be_falsey
            end
          end

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is non-zero' do
            it 'returns true' do
              expect(subject.mail_spammed?).to eq true
            end
          end
        end

        context 'and MAIL_EVENTS_WINDOW is non-zero' do
          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is zero' do
            let(:minimum_wait_before_another_usps_letter_in_hours) { 0 }

            it 'returns true' do
              expect(subject.mail_spammed?).to eq true
            end
          end

          context 'and MINIMUM_WAIT_BEFORE_ANOTHER_USPS_LETTER is non-zero' do
            it 'returns true' do
              expect(subject.mail_spammed?).to eq true
            end
          end
        end
      end
    end

    context 'when a user has a recent GPO request that is not attached to their pending profile' do
      let(:user) do
        user = create(:user, :deactivated_password_reset_profile, :with_pending_gpo_profile)

        # at this point, the gpo is attached to the pending profile. Move it.
        not_pending_profile = user.profiles.where.not(id: user.pending_profile.id).first
        GpoConfirmationCode.first.update(profile: not_pending_profile)

        user
      end

      it 'returns false' do
        expect(subject.mail_spammed?).to be_falsey
      end
    end
  end

  def enqueue_gpo_letter_for(user, at: Time.zone.now, with_profile: user.pending_profile)
    with_profile ||= create(:profile, user: user)

    GpoConfirmationMaker.new(
      pii: {},
      service_provider: nil,
      profile: with_profile,
    ).perform

    with_profile.gpo_confirmation_codes.last.update(
      created_at: at,
      updated_at: at,
    )

    event_create(event_type: :gpo_mail_sent, user: user, updated_at: at)
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
      created_at: updated_at, updated_at: updated_at
    )
  end
end
