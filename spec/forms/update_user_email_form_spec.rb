require 'rails_helper'

describe UpdateUserEmailForm do
  subject { UpdateUserEmailForm.new(build(:user, email: ' OLD@example.com ')) }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' OLD@example.com '

  describe '#email_changed?' do
    it 'is false when the submitted email is the same as the current email' do
      extra = {
        email_already_exists: false,
        email_changed: false,
      }
      result = instance_double(FormResponse)

      expect(FormResponse).to receive(:new).
        with(success: true, errors: {}, extra: extra).and_return(result)
      expect(subject.submit(email: 'OLD@example.com ')).to eq result
      expect(subject.email_changed?).to eq false
    end
  end

  describe '#submit' do
    context "when the user attempts to change their email to another user's email" do
      it 'sends an email alerting the other user' do
        user = create(:user, email: 'old@example.com')
        subject = UpdateUserEmailForm.new(user)
        _second_user = create(:user, :signed_up, email: 'another@example.com')
        mailer = instance_double(ActionMailer::MessageDelivery)
        result = instance_double(FormResponse)
        extra = {
          email_already_exists: true,
          email_changed: true,
        }

        expect(user).to receive(:skip_confirmation_notification!).and_call_original
        expect(UserMailer).to receive(:signup_with_your_email).
          with('another@example.com').and_return(mailer)
        expect(mailer).to receive(:deliver_later)
        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(email: 'ANOTHER@example.com')).to eq result
        expect(subject.email_changed?).to eq true
        expect(user.unconfirmed_email).to be_nil
        expect(user.email).to eq 'old@example.com'
      end
    end

    context 'when the user changes their email to a nonexistent email' do
      it "updates the user's unconfirmed_email" do
        user = create(:user, email: 'old@example.com')
        subject = UpdateUserEmailForm.new(user)
        result = instance_double(FormResponse)
        extra = {
          email_already_exists: false,
          email_changed: true,
        }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(email: 'new@example.com')).to eq result
        expect(user.unconfirmed_email).to eq 'new@example.com'
        expect(user.email).to eq 'old@example.com'
        expect(subject.email_changed?).to eq true
      end
    end

    context 'when email is already taken' do
      it 'returns FormResponse with success: true to prevent revealing account existence' do
        create(:user, :signed_up, email: 'taken@gmail.com')

        result = instance_double(FormResponse)
        extra = {
          email_already_exists: true,
          email_changed: true,
        }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(email: 'TAKEN@gmail.com')).to eq result
        expect(subject.email).to eq 'taken@gmail.com'
      end
    end

    context 'when email is invalid' do
      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)
        extra = {
          email_already_exists: false,
          email_changed: false,
        }
        errors = { email: [t('valid_email.validations.email.invalid')] }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit(email: 'invalid_email')).to eq result
      end
    end

    context 'when email is same as current email' do
      it 'it does not send an email' do
        user = create(:user, :signed_up, email: 'taken@gmail.com')
        form = UpdateUserEmailForm.new(user)

        result = instance_double(FormResponse)
        extra = {
          email_already_exists: false,
          email_changed: false,
        }

        expect(user).to_not receive(:send_custom_confirmation_instructions)
        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit(email: 'taken@gmail.com')).to eq result
        expect(form.email).to eq 'taken@gmail.com'
      end
    end
  end
end
