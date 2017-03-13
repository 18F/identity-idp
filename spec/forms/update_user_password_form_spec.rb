require 'rails_helper'

describe UpdateUserPasswordForm, type: :model do
  let(:password) { 'fancy password' }
  let(:user) { User.new(password: password) }
  subject { UpdateUserPasswordForm.new(user) }

  it_behaves_like 'password validation'

  describe '#valid?' do
    context 'when the form is invalid' do
      it 'returns false' do
        subject.submit('new')

        expect(subject.valid?).to eq false
      end
    end

    context 'when the form is valid' do
      it 'returns true' do
        subject.submit('salty new password')

        expect(subject.valid?).to eq true
      end
    end
  end

  describe '#submit' do
    it 'assigns the passed in password to the form' do
      subject.submit('new strong password')

      expect(subject.password).to eq 'new strong password'
    end
  end
end
