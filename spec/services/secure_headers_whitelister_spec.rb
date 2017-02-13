require 'rails_helper'

RSpec.describe SecureHeadersWhitelister do
  describe '.extract_domain' do
    def extract_domain(url)
      SecureHeadersWhitelister.extract_domain(url)
    end

    it 'extracts the domain and port from a url' do
      aggregate_failures do
        expect(extract_domain('http://localhost:1234/foo/bar')).to eq('localhost:1234')
        expect(extract_domain('https://example.com')).to eq('example.com')
        expect(extract_domain('https://example.com/test')).to eq('example.com')
        expect(extract_domain('https://example.com:1234')).to eq('example.com:1234')
      end
    end
  end
end
