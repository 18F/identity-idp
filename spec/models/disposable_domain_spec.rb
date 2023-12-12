require 'rails_helper'

RSpec.describe DisposableDomain do
  let(:domain) { 'temporary.com' }

  describe '.is_disposable?' do
    before do
      DisposableDomain.create(name: domain)
    end

    context 'when the domain exists' do
      it 'returns true' do
        expect(DisposableDomain.is_disposable?(domain)).to eq true
      end
    end

    context 'when the domain does not exist' do
      it 'returns false' do
        expect(DisposableDomain.is_disposable?('example.com')).to eq false
      end
    end

    context 'with bad data' do
      it 'returns false' do
        expect(DisposableDomain.is_disposable?('')).to eq false
        expect(DisposableDomain.is_disposable?(nil)).to eq false
        expect(DisposableDomain.is_disposable?({})).to eq false
      end
    end
  end
end
