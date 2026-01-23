require 'rails_helper'

RSpec.describe AuthAppConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'name validations' do
    context 'when a user supplies a name longer than max allowable characters' do
      before do
        subject.name = Faker::Lorem.characters(
          number: UserSuppliedNameAttributes::MAX_NAME_LENGTH + 1,
        )
      end
      it { is_expected.not_to be_valid }
    end

    context 'when a user supples a name with the max allowable character length' do
      before do
        subject.name = Faker::Lorem.characters(number: UserSuppliedNameAttributes::MAX_NAME_LENGTH)
      end
      it { is_expected.to be_valid }
    end
  end
end
