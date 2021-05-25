require 'rails_helper'

RSpec.describe Agreements::Reports::AgenciesReport do
  it 'uploads the JSON serialization of the passed agencies' do
    agency = build(:agency)
    expected = Agreements::AgencyBlueprint.render([agency], root: :agencies)

    expect(described_class.new(agencies: [agency]).run).to eq(expected)
  end

  describe '#report_path' do
    it 'saves to the root directory' do
      report = described_class.new(agencies: [build(:agency)])

      expect(report.report_path).to eq('')
    end
  end
end
