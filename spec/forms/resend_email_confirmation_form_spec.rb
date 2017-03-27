require 'rails_helper'

describe ResendEmailConfirmationForm do
  let(:request_id) { SecureRandom.uuid }
  let(:params) { { email: ' Test@example.com ', request_id: request_id } }
  subject { ResendEmailConfirmationForm.new(params) }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' Test@example.com '

  describe '#submit' do
    context 'when email is valid, and user exists and is not confirmed' do
      it 'returns FormResponse with success: true and sends confirmation email' do
        user = create(:user, :unconfirmed)
        subject = ResendEmailConfirmationForm.new(email: user.email, request_id: request_id)

        extra = {
          user_id: user.uuid,
          confirmed: false,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.user).to receive(:send_custom_confirmation_instructions).with(request_id)
        expect(subject.submit).to eq result
        expect(subject.email).to eq user.email
      end
    end

    context 'when email is valid and user does not exist' do
      it 'returns FormResponse with success: true but does not send an email' do
        extra = {
          user_id: 'nonexistent-uuid',
          confirmed: false,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.user).to_not receive(:send_custom_confirmation_instructions)
        expect(subject.submit).to eq result
      end
    end

    context 'when email is invalid' do
      it 'returns FormResponse with success: false and does not send an email' do
        subject = ResendEmailConfirmationForm.new(email: 'invalid')

        extra = {
          user_id: 'nonexistent-uuid',
          confirmed: false,
        }
        errors = { email: [t('valid_email.validations.email.invalid')] }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.user).to_not receive(:send_custom_confirmation_instructions)
        expect(subject.submit).to eq result
      end
    end

    context 'when email is valid, and user exists and is already confirmed' do
      it 'returns FormResponse with success: true and does not send an email' do
        user = create(:user, :signed_up)
        subject = ResendEmailConfirmationForm.new(email: user.email, request_id: request_id)

        extra = {
          user_id: user.uuid,
          confirmed: true,
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.user).to_not receive(:send_custom_confirmation_instructions).with(request_id)
        expect(subject.submit).to eq result
        expect(subject.email).to eq user.email
      end
    end
  end
end
