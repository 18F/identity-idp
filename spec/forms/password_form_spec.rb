require 'rails_helper'

describe PasswordForm, type: :model do
  subject(:form) { described_class.new(user) }
  let(:user) { build_stubbed(:user, uuid: '123') }
  let(:password) { 'Valid Password!' }
  let(:password_confirmation) { nil }
  let(:extra) do
    {
      user_id: user.uuid,
      request_id_present: request_id_present,
    }
  end

  it_behaves_like 'password validation'
  it_behaves_like 'strong password', 'PasswordForm'

  describe '#submit' do
    subject(:result) { form.submit(params) }
    let(:params) do
      {
        password: password,
        password_confirmation: password_confirmation,
      }
    end

    context 'when the form is valid' do
      let(:request_id_present) { false }

      it 'returns true' do
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end

      context 'with password confirmation' do
        subject(:form) { described_class.new(user, validate_confirmation) }

        let(:validate_confirmation) do
          { validate_confirmation: true }
        end

        let(:password_confirmation) { password }

        it 'returns false' do
          expect(result.success?).to eq true
        end
      end
    end

    context 'when the form is invalid' do
      let(:password) { 'invalid' }

      context 'when password is invalid' do
        let(:validation_error) do
          t(
            'errors.attributes.password.too_short.other',
            count: Devise.password_length.first,
          )
        end
        let(:request_id_present) { false }

        it 'returns false' do
          expect(result.success?).to eq false
          expect(result.errors[:password]).to include validation_error
          expect(result.extra).to eq extra
        end
      end

      context 'with password confirmation' do
        subject(:form) { described_class.new(user, validate_confirmation) }

        let(:validate_confirmation) do
          { validate_confirmation: true }
        end

        context 'when the passwords are invalid' do
          let(:password_confirmation) { password }

          let(:validation_error) do
            [t(
              'errors.attributes.password.too_short.other',
              count: Devise.password_length.first,
            )]
          end

          it 'returns false' do
            expect(result.success?).to eq false
            expect(result.errors[:password]).to eq(validation_error)
          end
        end

        context 'when passwords do not match' do
          let(:password_confirmation) { 'invalid_password_confirmation!' }

          it 'returns false' do
            expect(result.success?).to eq false
            expect(result.errors[:password_confirmation]).
              to include(t('errors.messages.password_mismatch'))
          end
        end

        context 'when password confirmation is nil' do
          let(:password_confirmation) { nil }

          it 'returns false' do
            expect(result.success?).to eq false
            expect(result.errors[:password_confirmation]).to include(t('errors.messages.blank'))
          end
        end
      end
    end

    context 'with request_id in the params' do
      let(:params) do
        {
          password: password,
          request_id: request_id,
        }
      end
      let(:request_id) { 'foo' }
      let(:request_id_present) { true }

      it 'tracks that it is present' do
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end

      context 'when the request_id is not properly encoded' do
        let(:request_id) { "\xFFbar\xF8" }

        it 'does not throw an exception' do
          expect(result.success?).to eq true
          expect(result.extra).to eq extra
        end
      end
    end
  end
end
