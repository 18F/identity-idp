require 'rails_helper'

RSpec.describe DurationParser do
  subject(:parser) { DurationParser.new(value) }

  describe '#parse' do
    context 'with a format in days' do
      let(:value) { '3d' }
      it 'parses the value as a number of days' do
        expect(parser.parse).to eq(3.days)
      end
    end

    context 'with a format in weeks' do
      let(:value) { '8w' }
      it 'parses the value as a number of 7-day weeks' do
        expect(parser.parse).to eq((8 * 7).days)
      end
    end

    context 'with a format in months' do
      let(:value) { '5m' }
      it 'parses the value as a number of 30-day months' do
        expect(parser.parse).to eq((5 * 30).days)
      end
    end

    context 'with a format in years' do
      let(:value) { '2y' }
      it 'parses the value as a number of 365-day years' do
        expect(parser.parse).to eq((2 * 365).days)
      end
    end

    [
      '123x', # bad suffix
      '1 d',    # interior space
      'aaa',    # not numeric
    ].each do |bad_format|
      context "with a bad format (#{bad_format})" do
        let(:value) { bad_format }
        it 'is not valid' do
          expect(parser.parse).to eq(nil)
        end
      end
    end
  end

  describe '#valid?' do
    context 'with an empty value' do
      let(:value) { ' ' }
      it 'is valid' do
        expect(parser.valid?).to eq(true)
      end
    end

    context 'with a real value' do
      let(:value) { '1w' }
      it 'is valid' do
        expect(parser.valid?).to eq(true)
      end
    end

    context 'with a bad value' do
      let(:value) { '1 a 1 a 1' }
      it 'is not valid' do
        expect(parser.valid?).to eq(false)
      end
    end
  end
end
