require 'rails_helper'

RSpec.describe Agreements::Reports::AgencyAgreementsReport do
  subject { described_class.new }

  before do
    clear_agreements_data
  end

  # These are really testing the query, so this might be better as query object
  # tests and that's it, since there are multiple save_report calls so we can't
  # assert against any individual body.
  it 'is empty by default' do
    expect(subject.call).to eq({})
  end

  xit 'returns the list of agreements in an agency' do
    # create a GTC with two orders
    # create a separate GTC + order in the same agency
    # stub out auths and ial2 users
    first_agency = create(:agency)
    first_agency_accounts = create_pair(:partner_account, agency: first_agency)
    second_agency_order = create(:iaa_order)
    second_agency = second_agency_account.agency

    expect(subject.call).to eq(
      {
        first_agency.abbreviation => first_agency_accounts,
        second_agency.abbreviation => [second_agency_account],
      },
    )
  end
end
