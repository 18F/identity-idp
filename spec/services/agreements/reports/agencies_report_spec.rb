require 'rails_helper'

RSpec.describe Agreements::Reports::AgenciesReport do
  it 'uploads the JSON serialization of the passed agencies' do
    agency = build(:agency)
    expected = Agreements::AgencyBlueprint.render([agency], root: :agencies)

    expect(described_class.new(agencies: [agency]).run).to eq(expected)
  end
end
