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

  describe '#identities' do
    it 'returns empty array' do
      expect(subject.identities).to eq([])
    end
  end

  context 'matching methods on ServiceProvider' do
    it 'has all the methods that ServiceProvider has' do
      sp_methods = ServiceProvider.instance_methods(false)
      ignored_methods = %i[
        autosave_associated_records_for_agency
        autosave_associated_records_for_identities
        belongs_to_counter_cache_after_update
        validate_associated_records_for_identities
      ]
      null_sp_methods = NullServiceProvider.instance_methods

      expect(sp_methods - ignored_methods - null_sp_methods).to be_empty
    end

    it 'has stubs for all the column names' do
      attributes = ServiceProvider.columns.map(&:name).map(&:to_sym)
      null_sp_methods = NullServiceProvider.instance_methods

      expect(attributes - null_sp_methods).to be_empty
    end
  end

  describe '#allow_prompt_login' do
    it 'returns false' do
      expect(subject.allow_prompt_login).to eq(false)
    end
  end

  describe '#app_id' do
    it 'returns nil' do
      expect(subject.app_id).to be_nil
    end
  end
end
