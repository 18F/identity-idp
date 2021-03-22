require 'rails_helper'

RSpec.describe Agreements::Reports::AgenciesReport do
  subject { described_class.new }

  before do
    clear_agreements_data
    Agency.delete_all
  end

  it 'is empty by default' do
    expect(subject.call).to eq('[]')
  end

  it 'returns the agencies with accounts of a specific status' do
    account = create(:partner_account)
    create(:partner_account) # has a different status and agency
    status = account.partner_account_status.name
    agency = account.agency
    expected = [{ name: agency.name, abbreviation: agency.abbreviation }].to_json

    expect(subject.call(status)).to eq(expected)
    expect(JSON.parse(subject.call(status)).length).to be < Agency.count
  end
end
