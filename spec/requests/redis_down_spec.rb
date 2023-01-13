require 'rails_helper'

RSpec.describe 'redis down session error handling' do
  context 'with bad Redis connection' do
    it 'fails loudly' do
      allow(REDIS_SESSION_POOL_WRAPPER).to receive(:setex).and_raise(Redis::CannotConnectError)
      expect do
        get forgot_password_path
      end.to raise_error(Redis::CannotConnectError)
    end
  end
end
