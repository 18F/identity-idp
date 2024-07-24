require 'rails_helper'

RSpec.describe FedEmailDomains do
  describe '#call' do
    let(:valid_email_domains) do
      %w[
        gsa.gov
        dotgov.gov
        fedjobs.gov
      ]
    end
    let(:invalid_email_domains) do
      %w[
        gsp.gov
        fake.mil
        test.com
      ]
    end

    it 'returns true for pwned passwords' do
      valid_email_domains.each do |domain|
        expect(FedEmailDomains.email_is_fed_domain?(domain)).to be true
      end
    end

    it 'returns false for non pwned passwords' do
      invalid_email_domains.each do |domain|
        expect(FedEmailDomains.email_is_fed_domain?(domain)).to be false
      end
    end
  end
end
