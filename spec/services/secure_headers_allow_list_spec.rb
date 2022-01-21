require 'rails_helper'

RSpec.describe SecureHeadersAllowList do
  describe '.csp_with_sp_redirect_uris' do
    def csp_with_sp_redirect_uris(domain, sp_redirect_uris)
      SecureHeadersAllowList.csp_with_sp_redirect_uris(domain, sp_redirect_uris)
    end

    it 'generates the proper CSP array from action_url domain and ServiceProvider#redirect_uris' do
      aggregate_failures do
        domain = 'https://example1.com'
        test_sp_uris = ['x-example-app://test', 'https://example2.com']
        full_return = ["'self'", 'https://example1.com', 'x-example-app://', 'https://example2.com']

        expect(csp_with_sp_redirect_uris(domain, test_sp_uris)).to eq(full_return)

        expect(csp_with_sp_redirect_uris(domain, test_sp_uris[0..0])).to eq(full_return[0..2])

        expect(csp_with_sp_redirect_uris(domain, [])).to eq(full_return[0..1])
        expect(csp_with_sp_redirect_uris(domain, nil)).to eq(full_return[0..1])
      end
    end

    it 'properly reduces web uris' do
      redirect_uri = 'https://example1.com/auth/result'
      allowed_redirect_uris = [
        'https://example1.com/auth/result',
        'https://example1.com/',
        'http://example2.com/',
        'https://example3.com:3000/',
      ]

      result = csp_with_sp_redirect_uris(redirect_uri, allowed_redirect_uris)

      expect(result).to match_array(
        ["'self'", 'https://example1.com', 'http://example2.com', 'https://example3.com:3000'],
      )
    end

    it 'properly reduces mobile uris' do
      redirect_uri = 'mymobileapp://result'
      allowed_redirect_uris = [
        'mymobileapp://result',
        'mymobileapp://result2',
        'myothermobileapp://result',
        'https://example.com/',
      ]

      result = csp_with_sp_redirect_uris(redirect_uri, allowed_redirect_uris)

      expect(result).to match_array(
        ["'self'", 'mymobileapp://', 'myothermobileapp://', 'https://example.com'],
      )
    end

    it 'handles nil sp_redirect_uris' do
      redirect_uri = 'https://example.com/auth/result'

      result = csp_with_sp_redirect_uris(redirect_uri, nil)

      expect(result).to match_array(
        ["'self'", 'https://example.com'],
      )
    end

    it 'handles sp_redirect_uris with nil elements' do
      redirect_uri = 'https://example1.com/auth/result'
      allowed_redirect_uris = [
        'https://example1.com/auth/result',
        nil,
        'http://example2.com/',
      ]

      result = csp_with_sp_redirect_uris(redirect_uri, allowed_redirect_uris)

      expect(result).to match_array(
        ["'self'", 'https://example1.com', 'http://example2.com'],
      )
    end
  end
end
