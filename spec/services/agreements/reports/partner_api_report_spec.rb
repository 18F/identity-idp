require 'rails_helper'

RSpec.describe Agreements::Reports::PartnerApiReport do
  before do
    store = double(RedactedStruct).tap do |s|
      allow(s).to receive(:enable_partner_api).and_return(true)
      allow(s).to receive(:s3_reports_enabled).and_return(false)
    end
    allow(IdentityConfig).to receive(:store).and_return(store)
  end

  it 'runs a series of reports' do
    # just a smoke test
    expect(described_class.new.run).to eq(true)
  end
end
