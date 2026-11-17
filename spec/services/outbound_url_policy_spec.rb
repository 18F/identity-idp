# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutboundUrlPolicy do
  let(:production) { true }

  def decide(url)
    described_class.decide(url, production:)
  end

  describe '.decide' do
    it 'allows a public https address' do
      expect(decide('https://203.0.113.10/push')).to have_attributes(allowed?: true, reason: nil)
    end

    it 'allows a host name over https without resolving it' do
      expect(Resolv).not_to receive(:getaddresses)
      expect(decide('https://partner.example.gov/push').allowed?).to eq(true)
    end

    it 'allows a public IPv6 literal' do
      expect(decide('https://[2001:db8::10]/push').allowed?).to eq(true)
    end

    %w[10.0.0.5 172.16.3.4 192.168.1.1 100.64.0.1 169.254.169.254 0.0.0.0].each do |address|
      it "refuses the private or link-local address #{address}" do
        expect(decide("https://#{address}/push")).to have_attributes(
          allowed?: false, reason: :private_address,
        )
      end
    end

    it 'refuses IPv6 unique-local and link-local addresses' do
      expect(decide('https://[fd00::1]/push').reason).to eq(:private_address)
      expect(decide('https://[fe80::1]/push').reason).to eq(:private_address)
    end

    it 'refuses an IPv4-mapped IPv6 address by the IPv4 address it carries' do
      expect(decide('https://[::ffff:10.0.0.5]/push').reason).to eq(:private_address)
    end

    it 'refuses loopback addresses in production' do
      expect(decide('https://127.0.0.1/push').reason).to eq(:loopback_address)
      expect(decide('https://[::1]/push').reason).to eq(:loopback_address)
    end

    it 'refuses http in production' do
      expect(decide('http://203.0.113.10/push').reason).to eq(:scheme)
    end

    it 'refuses other schemes and malformed urls everywhere' do
      expect(decide('ftp://203.0.113.10/push').reason).to eq(:scheme)
      expect(decide('not a url').reason).to eq(:malformed)
      expect(decide('https://').reason).to eq(:host)
    end

    context 'outside production' do
      let(:production) { false }

      it 'allows http and loopback for the local reference applications' do
        expect(decide('http://localhost:9292/push').allowed?).to eq(true)
        expect(decide('http://127.0.0.1:9393/push').allowed?).to eq(true)
      end

      it 'still refuses private and link-local addresses' do
        expect(decide('http://169.254.169.254/latest').reason).to eq(:private_address)
        expect(decide('http://10.0.0.5/push').reason).to eq(:private_address)
      end
    end
  end

  describe '.allowed?' do
    it 'returns the decision as a boolean' do
      expect(described_class.allowed?('https://203.0.113.10/', production:)).to eq(true)
      expect(described_class.allowed?('https://10.0.0.5/', production:)).to eq(false)
    end
  end
end
