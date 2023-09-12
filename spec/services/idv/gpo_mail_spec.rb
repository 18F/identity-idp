require 'rails_helper'

RSpec.describe Idv::GpoMail do
  let(:user) { create(:user) }
  let(:subject) { Idv::GpoMail.new(user) }
  let(:max_mail_events) { 2 }
  let(:mail_events_window_days) { 30 }
  let(:minimum_wait_before_another_usps_letter_in_hours) { 24 }

  before do
    allow(IdentityConfig.store).to receive(:max_mail_events).
      and_return(max_mail_events)
    allow(IdentityConfig.store).to receive(:max_mail_events_window_in_days).
      and_return(mail_events_window_days)
    allow(IdentityConfig.store).to receive(:minimum_wait_before_another_usps_letter_in_hours).
      and_return(minimum_wait_before_another_usps_letter_in_hours)
  end

  describe '#mail_spammed?' do
    context 'when no mail has been sent' do
      it 'returns false' do
        expect(subject.mail_spammed?).to be_falsey
      end
    end

    context 'when the amount of sent mail is lower than the allowed maximum' do
      context 'but the most recent mail event is too recent' do
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

    context 'when we would normally be rate limited by both rules' do
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

    context 'when a user has a recent GPO request' do
      let(:user) do
        user = create(:user, :deactivated_password_reset_profile, :with_pending_gpo_profile)

        # at this point, the gpo is attached to the pending profile. Move it.
        not_pending_profile = user.profiles.where.not(id: user.pending_profile.id).first
        GpoConfirmationCode.first.update(profile: not_pending_profile)

        user
      end

      context 'that is not attached to their pending profile' do
        it 'returns false' do
          expect(subject.mail_spammed?).to be_falsey
        end
      end

      context 'and no pending profile' do
        before do
          user.send(:instance_variable_set, :@pending_profile, nil)
        end

        it 'returns false' do
          expect(subject.mail_spammed?).to be_falsey
        end
      end
    end
  end

  def enqueue_gpo_letter_for(user, at: Time.zone.now)
    profile = create(:profile, user: user)
    user.instance_variable_set(:@pending_profile, profile)

    GpoConfirmationMaker.new(
      pii: {},
      service_provider: nil,
      profile: profile,
    ).perform

    profile.gpo_confirmation_codes.last.update(
      created_at: at,
      updated_at: at,
    )
  end
end
