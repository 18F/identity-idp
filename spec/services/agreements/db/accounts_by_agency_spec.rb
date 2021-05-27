require 'rails_helper'

RSpec.describe Agreements::Db::AccountsByAgency do
  let(:agency1) { create(:agency) }
  let(:agency2) { create(:agency) }

  before { clear_agreements_data }

  describe '.call' do
    it 'returns all partner accounts grouped by agency' do
      account1, account2 = create_pair(:partner_account, agency: agency1)
      account3 = create(:partner_account, agency: agency2)
      expected = {
        agency1 => [account1, account2],
        agency2 => [account3],
      }

      expect(described_class.call).to eq(expected)
    end
  end
end
