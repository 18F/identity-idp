require 'rails_helper'

RSpec.describe 'redis down session error handling' do
  context 'with bad Redis connection' do
    it 'fails loudly' do
      allow_any_instance_of(Redis).to receive(:set).and_raise(Redis::CannotConnectError)
      expect do
        get forgot_password_path
      end.to raise_error(Redis::CannotConnectError)
    end
  end
end
