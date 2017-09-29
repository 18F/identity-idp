require 'rails_helper'

RSpec.describe HeadersFilter do
  let(:app) { double('App', call: nil) }

  let(:middleware) { HeadersFilter.new(app) }

  describe '#call' do
    it 'removes untrusted headers from the env' do
      env = {
        'HTTP_HOST' => 'foobar.com',
        'HTTP_X_FORWARDED_HOST' => 'evil.com',
      }

      middleware.call(env)

      expect(env).to_not have_key('HTTP_HOST')
      expect(env).to_not have_key('HTTP_X_FORWARDED_HOST')
    end

    it 'encodes headers as 8 bit ASCII' do
      env = {
        'HTTP_USER_AGENT' => 'Mózillá/5.0',
      }

      middleware.call(env)

      expect(env['HTTP_USER_AGENT'].ascii_only?).to eq(true)
    end
  end
end
