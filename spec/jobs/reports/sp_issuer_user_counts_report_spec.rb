require 'rails_helper'

RSpec.describe Reports::SpIssuerUserCountsReport do
  let(:name) { 'sp-issuer-user-counts-report' }
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:sinatra' }
  let(:email) { 'foo@bar.com' }
  let(:user) { create(:user) }
  let(:uuid) { 'foo' }
  let(:last_authenticated_at) { '2020-01-02 12:03:04 UTC' }

  subject { described_class.new }

  it 'sends out a report to the email listed with one total user' do
    create(
      :service_provider_identity,
      service_provider: issuer,
      user: user,
      uuid: uuid,
      last_authenticated_at: last_authenticated_at,
    )

    allow(IdentityConfig.store).to receive(:sp_issuer_user_counts_report_configs).and_return(
      [{ 'issuer' => issuer, 'emails' => [email] }],
    )
    expect(ReportMailer).to receive(:sp_issuer_user_counts_report).with(
      name: name, email: email, ial1_total: 1, ial2_total: 0, issuer: issuer, total: 1,
    ).and_call_original

    subject.perform(Time.zone.today)
  end
end
