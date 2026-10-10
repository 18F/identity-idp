require 'rails_helper'

# Outcomes for MyBenefits Assistant acting at Housing Assistance Records (Department of Housing
# Support) over one month.
RSpec.describe Reports::DelegationOutcomesReport do
  subject(:report) { described_class.new }

  let(:report_date) { Time.zone.local(2026, 8, 31).end_of_day }
  let(:in_month) { Time.zone.local(2026, 8, 12, 10) }
  let(:agency) { create(:agency, name: 'Department of Housing Support') }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency:,
      issuer: 'urn:gov:gsa:openidconnect:sp:housing_records',
      friendly_name: 'Housing Assistance Records'
    )
  end
  let!(:resource_server) do
    create(
      :token_exchange_resource_server, service_provider: application,
                                       identifier: 'https://records-api.housing.example.gov'
    )
  end
  let(:sp) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', friendly_name: 'MyBenefits Assistant'
    )
  end

  def approve(user, remember: true, rails_session_id: nil, proofed_in_session: false, now: in_month)
    identity = create(
      :service_provider_identity, user:, service_provider_record: sp,
                                  rails_session_id:
    )
    grant = TokenExchangeGrant.approve!(
      user:, service_provider: sp, application:, source: 'consent_screen', remember:,
      rails_session_id:, proofed_in_session:, now:
    )
    [grant, identity]
  end

  def exchange(grant, resource_server: self.resource_server)
    grant.update!(first_exchanged_at: grant.consented_at + 5.minutes)
    create(
      :token_exchange_token, grant:, resource_server:, service_provider: sp, user: grant.user
    )
  end

  before do
    allow(IdentityConfig.store).to receive_messages(
      s3_reports_enabled: false,
      delegation_outcomes_report_emails: [],
    )
  end

  it 'is only the header with no approvals' do
    expect(CSV.parse(report.perform(report_date))).to eq([described_class::HEADER])
  end

  context 'with approvals in the month' do
    before do
      # Exchanged; the person verified identity in the sign-in.
      grant, = approve(create(:user), proofed_in_session: true)
      exchange(grant)

      # Approved, then withdrawn by the person before any exchange.
      grant, = approve(create(:user))
      grant.revoke!(reason: AccountDelegationRevocation::REASON)

      # Approved, then the service provider connection was revoked before any exchange; proofed.
      grant, = approve(create(:user), proofed_in_session: true)
      grant.revoke!(reason: 'service_provider_revoked')

      # Approved for one authorization whose browser session has since been replaced.
      _, identity = approve(create(:user), remember: false, rails_session_id: 'old')
      identity.update!(rails_session_id: 'new')

      # Approved and still current, unexchanged: counted only as requested.
      approve(create(:user), remember: false, rails_session_id: 'live')

      # Re-approved: the superseded row is left out, the replacement counted once.
      user = create(:user)
      approve(user)
      replacement = TokenExchangeGrant.approve!(
        user:, service_provider: sp, application:, source: 'account_page', remember: true,
        now: in_month + 1.day
      )
      exchange(replacement)

      # Outside the month: ignored.
      approve(create(:user), now: in_month + 1.month)
    end

    it 'reports outcomes per service provider, agency and resource server' do
      csv = CSV.parse(report.perform(report_date), headers: true)

      expect(csv.length).to eq(1)
      expect(csv.first.to_h).to eq(
        'Service provider issuer' => sp.issuer,
        'Agency' => 'Department of Housing Support',
        'Resource server' => 'https://records-api.housing.example.gov',
        'Billing issuer has agreement' => 'false',
        'Requested' => '6',
        'Withdrawn before use' => '1',
        'Consented, not exchanged' => '2',
        'Exchanged' => '2',
        'Proofed in session, not exchanged' => '1',
      )
    end

    it 'shows an API as invoiced when its billing issuer has a partner agreement' do
      create(:integration, service_provider: application, issuer: application.issuer)

      csv = CSV.parse(report.perform(report_date), headers: true)
      expect(csv.first['Billing issuer has agreement']).to eq('true')
    end

    it 'counts exchanges per API of the application' do
      other_api = create(
        :token_exchange_resource_server, service_provider: application,
                                         identifier: 'https://documents-api.housing.example.gov'
      )
      grant, = approve(create(:user))
      exchange(grant, resource_server: other_api)

      csv = CSV.parse(report.perform(report_date), headers: true)
      by_api = csv.map { |row| [row['Resource server'], row['Exchanged']] }.to_h
      expect(by_api).to eq(
        'https://documents-api.housing.example.gov' => '1',
        'https://records-api.housing.example.gov' => '2',
      )
      expect(csv.map { |row| row['Requested'] }.uniq).to eq(['7'])
    end

    it 'saves both CSVs to S3 under the report month and emails them when configured' do
      allow(IdentityConfig.store).to receive_messages(
        s3_reports_enabled: true,
        delegation_outcomes_report_emails: ['team@example.com'],
      )
      allow(Identity::Hostdata).to receive(:env).and_return('int')
      %w[delegation-outcomes-report delegation-sign-ins-report].each do |name|
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          hash_including(path: "int/#{name}/2026/2026-08.#{name}.csv", content_type: 'text/csv'),
        )
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          hash_including(path: "int/#{name}/latest.#{name}.csv"),
        )
      end
      mailer = double(deliver_now: true)
      expect(ReportMailer).to receive(:tables_report).with(
        hash_including(
          to: ['team@example.com'],
          subject: 'Delegation outcomes report - August 2026',
          attachment_format: :csv,
        ),
      ).and_return(mailer)

      report.perform(report_date)
    end
  end

  describe '#sign_in_rows' do
    let(:user) { create(:user, :proofed) }

    before do
      report.instance_variable_set(:@report_date, report_date)
      # One sign-in waived by an exchange (an agency was billed instead), two still billed, a
      # non-billable repeat, an ordinary service provider's sign-in, and one outside the month.
      waived = create(
        :sp_return_log, user_id: user.id, issuer: sp.issuer, ial: 2, billable: true,
                        returned_at: in_month
      )
      agency_row = create(
        :sp_return_log, user_id: user.id, issuer: application.issuer, ial: 2, billable: true,
                        access_type: 'delegated', returned_at: in_month + 1.minute
      )
      SpReturnLogBillingAdjustment.create!(
        sp_return_log: waived, adjustment_type: :exclude_from_billing,
        delegated_return_log: agency_row, resolved_via: :cache
      )
      2.times do |i|
        create(
          :sp_return_log, user_id: user.id, issuer: sp.issuer, ial: 2, billable: true,
                          returned_at: in_month + (i + 1).days
        )
      end
      create(
        :sp_return_log, user_id: user.id, issuer: sp.issuer, ial: 2, billable: false,
                        returned_at: in_month
      )
      ordinary = create(:service_provider)
      create(
        :sp_return_log, user_id: user.id, issuer: ordinary.issuer, ial: 2, billable: true,
                        returned_at: in_month
      )
      create(
        :sp_return_log, user_id: user.id, issuer: sp.issuer, ial: 2, billable: true,
                        returned_at: in_month + 1.month
      )
    end

    it 'counts each delegating service provider’s sign-ins as billed or waived for the month' do
      expect(report.sign_in_rows).to eq(
        [{ service_provider_issuer: sp.issuer, billed: 2, waived: 1 }],
      )
    end
  end
end
