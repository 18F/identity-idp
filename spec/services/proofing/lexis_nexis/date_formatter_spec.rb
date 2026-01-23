require 'rails_helper'

RSpec.describe Proofing::LexisNexis::DateFormatter do
  let(:rdp_version) { :rdp_v2 }
  subject(:date_formatter) { described_class.new(date_string, rdp_version: rdp_version) }

  describe '#date' do
    subject(:date) { date_formatter.date }

    context 'with a YYYYMMDD formatted date' do
      let(:date_string) { '19930102' }

      it { is_expected.to eq(Date.new(1993, 1, 2)) }
    end

    context 'with a YYYY-MM-DD formatted date' do
      let(:date_string) { '1993-01-02' }

      it { is_expected.to eq(Date.new(1993, 1, 2)) }
    end
  end

  describe '#formatted_date' do
    let(:date_string) { '2020-04-15' }

    context 'RDP v2' do
      it 'is a hash of string values' do
        expect(date_formatter.formatted_date).to eq(
          Year: '2020',
          Month: '4',
          Day: '15',
        )
      end
    end

    context 'RDP V3' do
      let(:rdp_version) { :rdp_v3 }

      it 'is a hash of integer values' do
        expect(date_formatter.formatted_date).to eq(
          Year: 2020,
          Month: 4,
          Day: 15,
        )
      end
    end
  end
end
