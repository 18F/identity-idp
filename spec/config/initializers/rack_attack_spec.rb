require 'rails_helper'

RSpec.describe Rack::Attack do
  describe '::cache.store' do
    it 'is a pool, not just a plain redis instance' do
      expect(Rack::Attack.cache.store.redis).to be_kind_of(ConnectionPool)
    end
  end
end
