require 'rails_helper'

describe Idv::InPerson::CompletionSurveySender do
  describe '.send_completion_survey' do
    let(:user) { create(:user) }
    let(:issuer) { 'test_issuer' }

    it 'does nothing if the user should not receive a survey' do
      allow(user).to receive(:should_receive_in_person_completion_survey?).
        with(issuer).and_return(false)

      described_class.send_completion_survey(user, issuer)
      expect_delivered_email_count(0)
    end

    context 'user should receive a survey' do
      before do
        allow(user).to receive(:should_receive_in_person_completion_survey?).
          with(issuer).and_return(true)
      end

      it 'sends a survey to the user\'s confirmed email addresses' do
        create(:email_address, user: user)
        described_class.send_completion_survey(user, issuer)

        expect_delivered_email_count(2)
        expect_delivered_email(
          0, {
            to: [user.confirmed_email_addresses[0].email],
            subject: t('user_mailer.in_person_completion_survey.subject', app_name: APP_NAME),
          }
        )
        expect_delivered_email(
          1, {
            to: [user.confirmed_email_addresses[1].email],
            subject: t('user_mailer.in_person_completion_survey.subject', app_name: APP_NAME),
          }
        )
      end
      it 'marks the user as having received a survey' do
        described_class.send_completion_survey(user, issuer)
        expect(user.in_person_enrollments.find_by(issuer: issuer).follow_up_survey_sent).to eq true
      end
    end
  end
end
