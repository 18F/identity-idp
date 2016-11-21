require 'rails_helper'

RSpec.describe BasicAuthUrl do
  describe '.build' do
    it 'is the URL as-is with no username or password' do
      url = 'https://foo.example.com/bar'
      external_url = BasicAuthUrl.build(url, user: nil, password: nil)

      expect(external_url).to eq(url)
    end

    context 'with SP_NAME and SP_PASS set in the ENV' do
      before do
        ENV['SP_NAME'] = 'user'
        ENV['SP_PASS'] = 'secret'
      end

      after do
        ENV.delete('SP_NAME')
        ENV.delete('SP_PASS')
      end

      it 'uses the values in the ENV' do
        url = 'https://foo.example.com/bar'
        external_url = BasicAuthUrl.build(url)

        expect(external_url).to eq('https://user:secret@foo.example.com/bar')
      end
    end
  end
end
