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

  describe '.csp_with_sp_redirect_uris' do
    def csp_with_sp_redirect_uris(domain, sp_redirect_uris)
      SecureHeadersWhitelister.csp_with_sp_redirect_uris(domain, sp_redirect_uris)
    end

    it 'generates the proper CSP array from action_url domain and ServiceProvider#redirect_uris' do
      aggregate_failures do
        domain = 'example1.com'
        test_sp_uris = ['x-example-app://test', 'https://example2.com']
        full_return = ["'self'", 'example1.com', 'x-example-app://test', 'https://example2.com']

        expect(csp_with_sp_redirect_uris(domain, test_sp_uris)).to eq(full_return)

        expect(csp_with_sp_redirect_uris(domain, test_sp_uris[0..0])).to eq(full_return[0..2])

        expect(csp_with_sp_redirect_uris(domain, [])).to eq(full_return[0..1])
        expect(csp_with_sp_redirect_uris(domain, nil)).to eq(full_return[0..1])
      end
    end
  end
end
