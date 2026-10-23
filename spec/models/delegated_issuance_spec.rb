require 'rails_helper'

RSpec.describe DelegatedIssuance do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:actor_return_log) }
    it { is_expected.to belong_to(:target_return_log) }
  end

  describe '.generate_delegation_id' do
    it 'returns distinct prefixed identifiers' do
      first = described_class.generate_delegation_id
      second = described_class.generate_delegation_id

      expect(first).to start_with('dlg_')
      expect(second).to start_with('dlg_')
      expect(first).to_not eq(second)
    end
  end

  describe '#readonly?' do
    it 'makes historical issuance rows immutable after creation' do
      issuance = create(:delegated_issuance)

      expect(issuance).to be_readonly
      expect { issuance.update!(scope: 'changed') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe 'return-log consistency' do
    it 'requires the actor return log to belong to the same user and actor' do
      issuance = build(:delegated_issuance)
      issuance.actor_return_log = build(:sp_return_log, user: create(:user), issuer: 'other')

      expect(issuance).to_not be_valid
      expect(issuance.errors[:actor_return_log]).to include('is invalid')
    end

    it 'requires the target return log to belong to the same user and target' do
      issuance = build(:delegated_issuance)
      issuance.target_return_log = build(:sp_return_log, user: create(:user), issuer: 'other')

      expect(issuance).to_not be_valid
      expect(issuance.errors[:target_return_log]).to include('is invalid')
    end
  end
end
