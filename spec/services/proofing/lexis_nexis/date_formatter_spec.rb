require 'rails_helper'

RSpec.describe Proofing::LexisNexis::DateFormatter do
  subject(:date_formatter) { described_class.new(date_string) }

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

    it 'is a hash' do
      expect(date_formatter.formatted_date).to eq(
        Year: '2020',
        Month: '4',
        Day: '15',
      )
    end
  end
end
