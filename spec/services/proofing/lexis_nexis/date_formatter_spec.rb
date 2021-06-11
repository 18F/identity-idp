require 'rails_helper'

describe Proofing::LexisNexis::DateFormatter do
  subject(:date_formatter) { described_class.new(date_string) }

  describe '#date' do
    subject(:date) { date_formatter.date }

    context 'with a MM/DD/YYYY formatted date' do
      let(:date_string) { '01/02/1993' }

      it { is_expected.to eq(Date.new(1993, 1, 2)) }
    end

    context 'with a YYYYMMDD formatted date' do
      let(:date_string) { '19930102' }

      it { is_expected.to eq(Date.new(1993, 1, 2)) }
    end
  end

  describe '#formatted_date' do
    let(:date_string) { '04/15/2020' }

    it 'is a hash' do
      expect(date_formatter.formatted_date).to eq(
        Year: '2020',
        Month: '4',
        Day: '15'
      )
    end
  end

  describe '#yyyymmdd' do
    let(:date_string) { '01/31/2020' }

    it 'is a correctly-formatted string' do
      expect(date_formatter.yyyymmdd).to eq('20200131')
    end
  end
end
