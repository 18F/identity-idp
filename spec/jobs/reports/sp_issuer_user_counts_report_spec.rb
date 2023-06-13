require 'rails_helper'

RSpec.describe Reports::SpIssuerUserCountsReport do
  subject { described_class.new }

  let(:issuer) { 'example_sp' }
  let(:emails) {['example1@email.com', 'example2@email.com']}
  let(:name) { 'sp-issuer-report' }
  let(:user) {create(:user)}
  let(:sp) {create(:service_provider, issuer: issuer)}
  let(:identity) {create(:service_provider_identity, :active, uuid: user.uuid, service_provider: issuer)}
  # spi1 = ServiceProviderIdentity.new(user: user, service_provider: sp)
  # spi1.update(service_provider: sp.issuer)
  # spi1.save
  # spi1.service_provider
  # user.reload


  it 'has expected dummy data' do
    binding.pry
    allow(IdentityConfig.store).to receive(:sp_issuer_user_counts_report_configs).
    and_return([{ 'name' => name, 'issuer' => issuer, 'emails' => emails }])
    report = JSON.parse(subject.perform(Time.zone.today))

    expect(report).to eq(
      [
        {
          issuer: issuer,
          total: 1,
          ial1_total: 1,
          ial2_total: 0,
        },
      ],
    )
  end

end
