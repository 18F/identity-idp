require 'rails_helper'

RSpec.describe BasicAuthUrl do
  describe '.build' do
    it 'is the URL as-is with no username or password' do
      url = 'https://foo.example.com/bar'
      external_url = BasicAuthUrl.build(url, user: nil, password: nil)

      expect(external_url).to eq(url)
    end

    context 'with basic auth username and pass set in the config' do
      it 'uses the values in from application.yml/Figaro' do
        url = 'https://foo.example.com/bar'
        external_url = BasicAuthUrl.build(url)

        expect(external_url).to eq('https://user:secret@foo.example.com/bar')
      end
    end
  end
end
