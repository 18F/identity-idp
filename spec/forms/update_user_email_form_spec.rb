require 'rails_helper'

describe UpdateUserEmailForm do
  subject { UpdateUserEmailForm.new(User.new(email: ' OLD@example.com ')) }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' OLD@example.com '

  describe '#email_changed?' do
    it 'is false when the submitted email is the same as the current email' do
      result = subject.submit(email: 'OLD@example.com ')

      result_hash = {
        success: true,
        errors: [],
        email_already_exists: false,
        email_changed: false,
      }

      expect(result).to eq result_hash
      expect(subject.email_changed?).to eq false
    end
  end

  describe '#submit' do
    context "when the user attempts to change their email to another user's email" do
      it 'sends an email alerting the other user' do
        user = create(:user, email: 'old@example.com')
        subject = UpdateUserEmailForm.new(user)
        _second_user = create(:user, :signed_up, email: 'another@example.com')

        expect(user).to receive(:skip_confirmation_notification!).and_call_original

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).
          with('another@example.com').and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        result = subject.submit(email: 'ANOTHER@example.com')

        result_hash = {
          success: true,
          errors: [],
          email_already_exists: true,
          email_changed: true,
        }

        expect(result).to eq result_hash
        expect(subject.email_changed?).to eq true
        expect(user.unconfirmed_email).to be_nil
        expect(user.email).to eq 'old@example.com'
      end
    end

    context 'when the user changes their email to a nonexistent email' do
      it "updates the user's unconfirmed_email" do
        user = create(:user, email: 'old@example.com')
        subject = UpdateUserEmailForm.new(user)

        result = subject.submit(email: 'new@example.com')

        result_hash = {
          success: true,
          errors: [],
          email_already_exists: false,
          email_changed: true,
        }

        expect(user.unconfirmed_email).to eq 'new@example.com'
        expect(user.email).to eq 'old@example.com'
        expect(result).to eq result_hash
        expect(subject.email_changed?).to eq true
      end
    end

    context 'when email is already taken' do
      it 'returns true to prevent revealing account existence' do
        create(:user, :signed_up, email: 'taken@gmail.com')

        result = subject.submit(email: 'TAKEN@gmail.com')

        result_hash = {
          success: true,
          errors: [],
          email_already_exists: true,
          email_changed: true,
        }

        expect(result).to eq result_hash
        expect(subject.email).to eq 'taken@gmail.com'
      end
    end

    context 'when email is invalid' do
      it 'returns false and adds errors to the form object' do
        result = subject.submit(email: 'invalid_email')

        result_hash = {
          success: false,
          errors: [t('valid_email.validations.email.invalid')],
          email_already_exists: false,
          email_changed: false,
        }

        expect(result).to eq result_hash
      end
    end
  end
end
