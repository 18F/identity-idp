require 'rails_helper'

RSpec.describe EventDisavowal::PasswordResetFromDisavowalForm, type: :model do
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

  context 'user has an active profile' do
    let(:user) { create(:user, :proofed) }

    it 'destroys the proofing component' do
      ProofingComponent.create(user_id: user.id, document_check: 'acuant')

      subject.submit(password: new_password)

      expect(user.reload.proofing_component).to be_nil
    end
  end

  context 'user does not have an active profile' do
    it 'does not destroy the proofing component' do
      ProofingComponent.create(user_id: user.id, document_check: 'acuant')

      subject.submit(password: new_password)

      expect(user.reload.proofing_component).to_not be_nil
    end
  end
end
