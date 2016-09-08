require 'rails_helper'

describe UpdateUserEmailForm do
  subject { UpdateUserEmailForm.new(User.new(email: 'old@gmail.com')) }

  it_behaves_like 'email validation'

  describe '#email_changed?' do
    it 'is false when the submitted email is the same as the current email' do
      result = subject.submit(email: 'OLD@gmail.com')

      expect(result).to be true
      expect(subject.email_changed?).to eq false
    end
  end

  describe '#submit' do
    context "when the user attempts to change their email to another user's email" do
      it 'sends an email alerting the other user' do
        user = create(:user, email: 'old@gmail.com')
        subject = UpdateUserEmailForm.new(user)
        _second_user = create(:user, :signed_up, email: 'another@gmail.com')

        expect(user).to receive(:skip_confirmation_notification!).and_call_original

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).
          with('another@gmail.com').and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        result = subject.submit(email: 'ANOTHER@gmail.com')

        expect(result).to be true
        expect(subject.email_changed?).to eq true
        expect(user.unconfirmed_email).to be_nil
        expect(user.email).to eq 'old@gmail.com'
      end
    end

    context 'when the user changes their email to a nonexistent email' do
      it "updates the user's unconfirmed_email" do
        user = create(:user, email: 'old@gmail.com')
        subject = UpdateUserEmailForm.new(user)

        result = subject.submit(email: 'new@example.com')

        expect(user.unconfirmed_email).to eq 'new@example.com'
        expect(user.email).to eq 'old@gmail.com'
        expect(result).to be true
        expect(subject.email_changed?).to eq true
      end
    end
  end
end
