require 'rails_helper'

describe PasswordResetEmailForm do
  subject { PasswordResetEmailForm.new(' Test@example.com ', RecaptchaValidator.new) }

  it_behaves_like 'email validation'
  it_behaves_like 'email normalization', ' Test@example.com '

  describe '#submit' do
    context 'when email is valid and user exists' do
      it 'returns hash with properties about the event and the user' do
        user = build(:user, :signed_up, email: 'test1@test.com')
        subject = PasswordResetEmailForm.new(
          'Test1@test.com',
          mock_recaptcha(valid: true, present: true, enabled: true)
        )

        extra = {
          user_id: user.uuid,
          role: user.role,
          confirmed: true,
        }.merge(subject.recaptcha.extra_analytics_attributes)

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
        expect(subject).to respond_to(:resend)
      end
    end

    context 'when email is valid and user does not exist' do
      it 'returns hash with properties about the event and the nonexistent user' do
        extra = {
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false,
        }.merge(subject.recaptcha.extra_analytics_attributes)

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
      end
    end

    context 'when email is invalid' do
      it 'returns hash with properties about the event and the nonexistent user' do
        subject = PasswordResetEmailForm.new(
          'invalid',
          mock_recaptcha(valid: true, present: true, enabled: true)
        )

        errors = { email: [t('valid_email.validations.email.invalid')] }

        extra = {
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false,
        }.merge(subject.recaptcha.extra_analytics_attributes)

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(subject.submit).to eq result
      end
    end

    context 'when recaptcha is valid' do
      it 'returns hash with properties about the event and the user' do
        user = build(:user, :signed_up, email: 'test1@test.com')

        subject = PasswordResetEmailForm.new(
          'Test1@test.com',
          mock_recaptcha(valid: true, present: true, enabled: true)
        )

        extra = {
          user_id: user.uuid,
          role: user.role,
          confirmed: true,
        }.merge(subject.recaptcha.extra_analytics_attributes)

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
        expect(subject).to respond_to(:resend)
      end
    end

    context 'when recaptcha is invalid' do
      it 'returns hash with properties about the event and the user' do
        user = build(:user, :signed_up, email: 'test1@test.com')

        subject = PasswordResetEmailForm.new(
          'Test1@test.com',
          mock_recaptcha(valid: false, present: true, enabled: true)
        )

        extra = {
          user_id: user.uuid,
          role: user.role,
          confirmed: true,
        }.merge(subject.recaptcha.extra_analytics_attributes)

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(subject.submit).to eq result
        expect(subject).to respond_to(:resend)
      end
    end
  end

  def mock_recaptcha(valid:, present:, enabled:)
    instance_double(
      'RecaptchaValidator',
      valid?: valid,
      extra_analytics_attributes: {
        recaptcha_valid: valid,
        recaptcha_present: present,
        recaptcha_enabled: enabled,
      }
    )
  end
end
