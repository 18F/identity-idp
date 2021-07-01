require 'rails_helper'

RSpec.describe DateParser do
  describe '.parse_legacy' do
    subject(:parse) { DateParser.parse_legacy(val) }

    context 'with an american style date' do
      let(:val) { '12/31/1970' }

      it { is_expected.to eq(Date.new(1970, 12, 31)) }
    end

    context 'single digit american date month and year' do
      let(:val) { '2/1/1970' }

      it { is_expected.to eq(Date.new(1970, 2, 1)) }
    end

    context 'with an international style date' do
      let(:val) { '1970-12-31' }

      it { is_expected.to eq(Date.new(1970, 12, 31)) }
    end

    context 'with something that is not a date' do
      let(:val) { 'aaa' }

      it 'blows up' do
        expect { parse }.to raise_error
      end
    end

    context 'it passes through date objects' do
      let(:val) { Date.new(2020, 1, 1) }

      it 'is the date' do
        expect(parse).to eq(val)
      end
    end
  end
end
