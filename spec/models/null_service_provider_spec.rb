require 'rails_helper'

describe NullServiceProvider do
  subject { NullServiceProvider.new(issuer: 'foo') }

  describe '#active?' do
    it 'returns false' do
      expect(subject.active?).to eq false
    end
  end

  describe '#native?' do
    it 'returns false' do
      expect(subject.native?).to eq false
    end
  end

  describe '#live?' do
    it 'returns false' do
      expect(subject.live?).to eq false
    end
  end

  describe '#metadata' do
    it 'returns empty Hash' do
      empty_hash = {}
      expect(subject.metadata).to eq empty_hash
    end
  end

  describe '#fingerprint' do
    it 'returns nil' do
      expect(subject.fingerprint).to be_nil
    end
  end

  describe '#ssl_cert' do
    it 'returns nil' do
      expect(subject.ssl_cert).to be_nil
    end
  end

  describe '#logo' do
    it 'returns nil' do
      expect(subject.logo).to be_nil
    end
  end

  describe '#friendly_name' do
    it 'returns a default name' do
      expect(subject.friendly_name).to be_present
    end
  end

  describe '#return_to_sp_url' do
    it 'returns nil' do
      expect(subject.return_to_sp_url).to be_nil
    end
  end

  describe '#failure_to_proof_url' do
    it 'returns nil' do
      expect(subject.failure_to_proof_url).to be_nil
    end
  end

  describe '#issuer' do
    it 'returns the issuer argument' do
      expect(subject.issuer).to eq 'foo'
    end
  end

  describe '#redirect_uris' do
    it 'returns empty array' do
      expect(subject.redirect_uris).to eq([])
    end
  end
end
