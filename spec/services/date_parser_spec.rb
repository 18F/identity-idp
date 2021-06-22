require 'rails_helper'

RSpec.describe DateParser do
  describe '.parse' do
    subject(:parse) { DateParser.parse(str, allow_american: allow_american) }

    context 'with allow_american: false' do
      let(:allow_american) { false }

      context 'with an american style date' do
        let(:str) { '12/31/1970' }

        it 'blows up' do
          expect { parse }.to raise_error
        end
      end

      context 'with an international style date' do
        let(:str) { '1970-12-31' }

        it { is_expected.to eq(Date.new(1970, 12, 31)) }
      end

      context 'with something that is not a date' do
        let(:str) { 'aaa' }

        it 'blows up' do
          expect { parse }.to raise_error
        end
      end
    end

    context 'with allow_american: true' do
      let(:allow_american) { true }

      context 'with an american style date' do
        let(:str) { '12/31/1970' }

        it { is_expected.to eq(Date.new(1970, 12, 31)) }
      end

      context 'with an international style date' do
        let(:str) { '1970-12-31' }

        it { is_expected.to eq(Date.new(1970, 12, 31)) }
      end

      context 'with something that is not a date' do
        let(:str) { 'aaa' }

        it 'blows up' do
          expect { parse }.to raise_error
        end
      end
    end
  end
end
