require 'rails_helper'

RSpec.describe GpoReminderSender do
  describe '#send_emails' do
    let(:user) { create(:user, :with_pending_gpo_profile) }

    context 'when no users need a reminder' do
      before do
        user.gpo_verification_pending_profile.gpo_verification_pending_at = Time.zone.now - 13.days
        user.save
      end

      it 'sends no emails' do
        expect{subject.send_emails}.to change{ActionMailer::Base.deliveries.size}.by(0)
      end
    end

    context 'when a user is due for a reminder' do
      before do
        user.gpo_verification_pending_profile.gpo_verification_pending_at = Time.zone.now - 14.days
        user.save
      end

      it 'sends that user an email' do
        expect{subject.send_emails}.to change{ActionMailer::Base.deliveries.size}.by(1)
      end

      context 'but a reminder has already been sent' do
        before do
          user.gpo_verification_pending_profile.gpo_reminder_sent_at = Time.zone.now - 1.day
        end

        it 'does not send that user an email' do
          expect{subject.send_emails}.to change{ActionMailer::Base.deliveries.size}.by(0)
        end
      end
    end
  end
end
