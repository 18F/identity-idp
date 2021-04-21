require 'spec_helper'

RSpec.describe IdentityIdpFunctions::Timer do
  subject(:timer) do
    IdentityIdpFunctions::Timer.new
  end

  describe '#time' do
    before do
      allow(Time).to receive(:now).and_return(1111.01, 1112.02)
    end

    it 'measures the time in milliseconds it takes to execute a block' do
      timer.time('event') { 1 }

      expect(timer.results['event']).to eq(1010.0)
    end

    it 'measure the block even if the block raises' do
      expect do
        timer.time('event') { raise 'boom' }
      end.to raise_error('boom')

      expect(timer.results['event']).to eq(1010.0)
    end

    it 'returns the result of the block' do
      result = timer.time('event') { 100 }
      expect(result).to eq(100)
    end
  end
end
