require 'rails_helper'

RSpec.describe Agreements::Reports::PartnerApiReport do
  before do
    allow(IdentityConfig.store).to receive(:enable_partner_api).and_return(true)
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(false)
  end

  it 'runs a series of reports' do
    # just a smoke test
    expect(described_class.new.perform(Time.zone.today)).to eq(true)
  end
end
