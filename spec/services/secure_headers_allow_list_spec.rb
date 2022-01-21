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
  end
end
