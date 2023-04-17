require 'rails_helper'

describe PasswordConfirmationForm, type: :model do
  subject(:form) { described_class.new(user) }
  let(:user) { build_stubbed(:user, uuid: '123') }

  describe '#submit' do
    subject(:result) { form.submit(params) }
    let(:password) { 'Valid Password!' }
    let(:params) do
      {
        password: password,
        password_confirmation: password_confirmation,
      }
    end

    context 'when valid' do
      context 'when passwords match' do
        let(:password_confirmation) { password }

        it 'returns false' do
          expect(result.success?).to eq true
        end
      end
    end

    context 'when invalid' do
      context 'when passwords are invalid' do
        let(:password) { 'invalid' }
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
            to include("doesn't match Password confirmation")
        end
      end

      context 'without confirmation password' do
        let(:password_confirmation) { nil }

        it 'returns false' do
          expect(result.success?).to eq false
          expect(result.errors[:password_confirmation]).to include(t('errors.messages.blank'))
        end
      end
    end
  end
end
