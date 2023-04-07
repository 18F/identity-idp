require 'rails_helper'

describe PasswordForm, type: :model do
  let(:user) { build_stubbed(:user, uuid: '123') }
  subject(:form) { described_class.new(user) }
  let(:password) { 'Valid Password!' }
  let(:invalid_password) { 'invalid' }
  let(:extra) do
    {
      user_id: user.uuid,
      request_id_present: request_id_present,
    }
  end

  # it_behaves_like 'password validation'
  # it_behaves_like 'strong password', 'PasswordForm'

  describe '#submit' do
    subject(:result) { described_class.new(user).submit(params) }

    context 'when the form is valid' do
      let(:params) do
        {
          password: password,
          password_confirmation: password,
        }
      end
      let(:request_id_present) { false }

      it 'returns true' do
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end

    context 'when the form is invalid' do
      context 'when passwords are invalid' do
        let(:params) do
          {
            password: invalid_password,
            password_confirmation: invalid_password,
          }
        end
        let(:confirmation_error) do
          t(
            'errors.messages.too_short.other',
            count: Devise.password_length.first,
          )
        end
        let(:request_id_present) { false }

        it 'returns false' do
          expect(result.success?).to eq false
          expect(result.errors[:password_confirmation]).to include confirmation_error
          expect(result.extra).to eq extra
        end
      end

      context 'when passwords do not match' do
        let(:password_confirmation) { 'invalid_password_confirmation!' }
        let(:params) do
          {
            password: password,
            password_confirmation: password_confirmation,
          }
        end

        it 'returns false' do
          expect(result.success?).to eq false
          expect(result.errors[:password_confirmation]).to include("doesn't match Password confirmation")
        end
      end

      context 'when confirmation password is missing' do
        let(:params) do
          { password: password }
        end

        it 'returns false' do
          expect(result.success?).to eq false
          expect(result.errors[:password_confirmation]).to include(t('errors.messages.blank'))
        end
      end
    end

    context 'when the request_id is passed in the params' do
      let(:params) do
        {
          password: password,
          password_confirmation: password,
          request_id: 'foo',
        }
      end
      let(:request_id_present) { true }

      it 'tracks that it is present' do
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end

    context 'when the request_id is not properly encoded' do
      let(:params) do
        {
          password: password,
          password_confirmation: password,
          request_id: "\xFFbar\xF8",
        }
      end
      let(:request_id_present) { true }

      it 'does not throw an exception' do
        expect(result.success?).to eq true
        expect(result.extra).to eq extra
      end
    end
  end
end
