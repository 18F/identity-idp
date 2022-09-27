require 'rails_helper'

describe Idv::InPerson::CompletionSurveySender do
  describe '.send_completion_survey' do
    let(:user) { instance_double(User) }
    let(:issuer) { 'test_issuer' }

    it 'does nothing if the user should not receive a survey' do
      expect(UserMailer).to_not receive(:in_person_completion_survey)
      allow(user).to receive(:should_receive_in_person_completion_survey?).
        with(issuer).and_return(false)

      described_class.send_completion_survey(user, issuer)
    end

    context 'user should receive a survey' do
      let(:message) { instance_double(ActionMailer::MessageDelivery) }
      let(:message2) { instance_double(ActionMailer::MessageDelivery) }
      let(:email_address_one) { 'hello@world.com' }
      let(:email_address_two) { 'hola@mundo.com' }
      before do
        allow(user).to receive(:should_receive_in_person_completion_survey?).
          with(issuer).and_return(true)
        allow(user).to receive(:confirmed_email_addresses).
          and_return([
                       email_address_one,
                       email_address_two,
                     ])
        allow(UserMailer).to receive(:in_person_completion_survey).
          with(user, email_address_one).
          and_return(message)
        allow(UserMailer).to receive(:in_person_completion_survey).
          with(user, email_address_two).
          and_return(message2)
        allow(message).to receive(:deliver_now_or_later)
        allow(message2).to receive(:deliver_now_or_later)
        allow(user).to receive(:mark_in_person_completion_survey_sent).
          with(issuer)

        described_class.send_completion_survey(user, issuer)
      end
      it 'sends a survey to the user\'s confirmed email addresses' do
        expect(message).to have_received(:deliver_now_or_later)
        expect(message2).to have_received(:deliver_now_or_later)
      end
      it 'marks the user as having received a survey' do
        expect(user).to have_received(:mark_in_person_completion_survey_sent).
          with(issuer)
      end
    end
  end
end
