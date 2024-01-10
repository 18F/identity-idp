require 'rails_helper'

RSpec.describe DisposableEmailDomain do
  let(:domain) { 'temporary.com' }

  describe '.disposable?' do
    before do
      DisposableEmailDomain.create(name: domain)
    end

    context 'when the domain exists' do
      it 'returns true' do
        expect(DisposableEmailDomain.disposable?(domain)).to eq true
      end
    end

    context 'when the domain does not exist' do
      it 'returns false' do
        expect(DisposableEmailDomain.disposable?('example.com')).to eq false
      end
    end
  end
end
