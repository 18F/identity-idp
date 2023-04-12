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

    context 'when passwords match' do
      let(:password_confirmation) { password }

      it 'returns false' do
        expect(result.success?).to eq true
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

    context 'when confirmation password is missing' do
      let(:password_confirmation) { nil }

      it 'returns false' do
        expect(result.success?).to eq false
        expect(result.errors[:password_confirmation]).to include(t('errors.messages.blank'))
      end
    end
  end
end
