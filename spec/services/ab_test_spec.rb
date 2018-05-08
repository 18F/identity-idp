require 'rails_helper'

RSpec.describe AbTest do
  describe '#enabled' do
    context 'with percent set to 100' do
      let(:ab_test) { AbTest.new(:key, '100') }

      it 'it returns true for a new session' do
        expect(ab_test.enabled?({}, true)).to eq(true)
      end

      it 'it returns true for an old session' do
        session = {}
        expect(ab_test.enabled?(session, true)).to eq(true)
        expect(ab_test.enabled?(session, false)).to eq(true)
      end
    end

    context 'with percent set to 0' do
      let(:ab_test) { AbTest.new(:key, '0') }

      it 'it returns false for a new session' do
        expect(ab_test.enabled?({}, true)).to eq(false)
      end

      it 'it returns false for an old session' do
        session = {}
        expect(ab_test.enabled?(session, true)).to eq(false)
        expect(ab_test.enabled?(session, false)).to eq(false)
      end
    end

    context 'with percent set to 50' do
      let(:ab_test) { AbTest.new(:key, '50') }

      it 'it returns true or false for a new session' do
        enabled = ab_test.enabled?({}, true)
        expect(enabled == true || enabled == false).to eq(true)
      end

      it 'it returns the same value for the next session' do
        session = {}
        enabled = ab_test.enabled?(session, true)
        expect(ab_test.enabled?(session, false)).to eq(enabled)
      end

      it 'it returns enabled if the random number is 70' do
        allow(SecureRandom).to receive(:random_number).and_return(70)
        expect(ab_test.enabled?({}, true)).to eq(true)
      end

      it 'it returns disabled if the random number is 30' do
        allow(SecureRandom).to receive(:random_number).and_return(30)
        expect(ab_test.enabled?({}, true)).to eq(false)
      end
    end
  end
end
