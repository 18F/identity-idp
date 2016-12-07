require 'rails_helper'

describe UpdateUserPasswordForm, type: :model do
  let(:password) { 'fancy password' }
  let(:user) { User.new(password: password) }
  subject { UpdateUserPasswordForm.new(user) }

  it_behaves_like 'password validation'

  describe '#submit' do
    context 'when the form is invalid' do
      it 'returns false' do
        params = { password: 'new' }

        result = subject.submit(params)

        result_hash = {
          success: false,
          errors: subject.errors.full_messages
        }

        expect(result).to eq result_hash
      end
    end

    context 'when both the form and user are valid' do
      it 'sets the user password to the submitted password' do
        params = { password: 'salty new password' }

        expect(subject.errors).to receive(:full_messages).and_call_original

        result = subject.submit(params)

        result_hash = {
          success: true,
          errors: []
        }

        expect(result).to eq result_hash
      end
    end
  end
end
