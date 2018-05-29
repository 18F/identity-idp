require 'rails_helper'

describe RegisterUserEmailForm do
  subject { RegisterUserEmailForm.new }

  it_behaves_like 'email validation'

  describe '#submit' do
    context 'when email is already taken' do
      it 'sets success to true to prevent revealing account existence' do
        existing_user = create(:user, :signed_up, email: 'taken@gmail.com')

        mailer = instance_double(ActionMailer::MessageDelivery)
        allow(UserMailer).to receive(:signup_with_your_email).
          with(existing_user.email).and_return(mailer)
        allow(mailer).to receive(:deliver_later)

        extra = {
          email_already_exists: true,
          user_id: existing_user.uuid,
          domain_name: 'gmail.com',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(email: 'TAKEN@gmail.com')).to eq result
        expect(subject.email).to eq 'taken@gmail.com'
        expect(mailer).to have_received(:deliver_later)
      end
    end

    context 'when email is already taken and existing user is unconfirmed' do
      it 'sends confirmation instructions to existing user' do
        user = instance_double(User, email: 'existing@test.com', confirmed?: false, uuid: '123')
        allow(User).to receive(:find_with_email).with(user.email).and_return(user)

        expect(user).to receive(:send_custom_confirmation_instructions)

        extra = {
          email_already_exists: true,
          user_id: user.uuid,
          domain_name: 'test.com',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit(email: user.email)).to eq result
      end
    end

    context 'when email is not already taken' do
      it 'is valid' do
        result = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(result)
        submit_form = subject.submit(email: 'not_taken@gmail.com')
        extra = {
          email_already_exists: false,
          user_id: User.find_with_email('not_taken@gmail.com').uuid,
          domain_name: 'gmail.com',
        }

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
        expect(submit_form).to eq result
      end

      it 'is valid with valid recaptcha' do
        result = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(result)
        captcha_results = mock_captcha(enabled: true, present: true, valid: true)
        form = RegisterUserEmailForm.new(captcha_results)
        submit_form = form.submit(email: 'not_taken@gmail.com')
        extra = {
          email_already_exists: false,
          user_id: User.find_with_email('not_taken@gmail.com').uuid,
          domain_name: 'gmail.com',
          recaptcha_valid: true,
          recaptcha_present: true,
          recaptcha_enabled: true,
        }

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
        expect(submit_form).to eq result
      end

      it 'is invalid with invalid recaptcha' do
        result = instance_double(FormResponse)
        allow(FormResponse).to receive(:new).and_return(result)
        captcha_results = mock_captcha(enabled: true, present: true, valid: false)
        form = RegisterUserEmailForm.new(captcha_results)
        submit_form = form.submit(email: 'not_taken@gmail.com')
        extra = {
          email_already_exists: false,
          user_id: 'anonymous-uuid',
          domain_name: 'gmail.com',
          recaptcha_valid: false,
          recaptcha_present: true,
          recaptcha_enabled: true,
        }

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: {}, extra: extra)
        expect(submit_form).to eq result
      end
    end

    context 'when email is invalid' do
      it 'returns false and adds errors to the form object' do
        errors = { email: [t('valid_email.validations.email.invalid')] }

        extra = {
          email_already_exists: false,
          user_id: 'anonymous-uuid',
          domain_name: 'invalid_email',
        }

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit(email: 'invalid_email')).to eq result
      end
    end
  end

  def mock_captcha(enabled:, present:, valid:)
    allow = enabled ? valid : true
    [allow, {
      recaptcha_valid: valid,
      recaptcha_present: present,
      recaptcha_enabled: enabled,
    }]
  end
end
