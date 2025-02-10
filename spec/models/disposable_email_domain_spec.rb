require 'rails_helper'

RSpec.describe DisposableEmailDomain do
  let(:domain) { 'temporary.com' }

  describe '.disposable?' do
    before do
      DisposableEmailDomain.create(name: domain)
    end

    context 'when the domain exists' do
      it 'returns true for an exact domain match' do
        expect(DisposableEmailDomain.disposable?(domain)).to eq true
      end

      it 'returns true for an first subdomain match' do
        expect(DisposableEmailDomain.disposable?("temp1.#{domain}")).to eq true
      end

      it 'returns true for an sub-sub-subdomain match' do
        expect(DisposableEmailDomain.disposable?("foo.bar.temp1.#{domain}")).to eq true
      end
    end

    context 'when the domain does not exist' do
      it 'returns false' do
        expect(DisposableEmailDomain.disposable?('example.com')).to eq false
      end
    end
  end

  describe '.subdomains' do
    it 'breaks a domain into subdomains' do
      expect(DisposableEmailDomain.subdomains('foo.bar.baz.com')).to eq(
        %w[
          foo.bar.baz.com
          bar.baz.com
          baz.com
        ],
      )
    end
  end
end
