require 'rails_helper'

describe EventDisavowal::PasswordResetFromDisavowalForm, type: :model do
  let(:user) { create(:user, password: 'salty pickles') }
  let(:new_password) { 'saltier pickles' }
  let(:event) { create(:event, user: user) }

  subject { described_class.new(event) }

  it_behaves_like 'password validation'

  context 'with a valid password' do
    it 'resets the users password' do
      subject.submit(password: new_password)

      expect(user.reload.valid_password?(new_password)).to eq(true)
    end
  end

  context 'with an invalid password' do
    let(:new_password) { 'too short' }

    it 'does not reset the users passowrd' do
      subject.submit(password: new_password)

      expect(user.reload.valid_password?(new_password)).to eq(false)
    end
  end
end
