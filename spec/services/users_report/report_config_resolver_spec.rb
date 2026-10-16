require 'rails_helper'

RSpec.describe UsersReport::ReportConfigResolver do
  let(:issuer) { 'urn:gov:gsa:openidconnect:sp:example' }
  let(:agency_abbreviation) { 'ABC' }

  let(:report_configs) do
    [
      {
        'issuers' => [issuer, 'urn:gov:gsa:openidconnect:sp:example:mobile'],
        'agency_abbreviation' => agency_abbreviation,
        'emails' => ['test@example.com'],
      },
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:sp_proofing_events_by_uuid_report_configs).and_return(
      report_configs,
    )
  end

  subject(:resolver) { described_class.new(issuer) }

  describe '#report_config' do
    context 'with exactly one matching report config' do
      it 'returns the matched config' do
        expect(resolver.report_config).to eq(report_configs.first)
      end
    end

    context 'with no matching report config' do
      let(:report_configs) do
        [
          {
            'issuers' => ['urn:gov:gsa:openidconnect:sp:other'],
            'agency_abbreviation' => agency_abbreviation,
            'emails' => ['test@example.com'],
          },
        ]
      end

      it 'raises a ConfigurationError' do
        expect { resolver.report_config }.to raise_error(
          UsersReport::ReportConfigResolver::ConfigurationError,
        )
      end
    end

    context 'with multiple matching report configs' do
      let(:report_configs) do
        [
          {
            'issuers' => [issuer],
            'agency_abbreviation' => 'ABC',
            'emails' => ['test@example.com'],
          },
          {
            'issuers' => [issuer, 'urn:gov:gsa:openidconnect:sp:other'],
            'agency_abbreviation' => 'DEF',
            'emails' => ['test@example.com'],
          },
        ]
      end

      it 'raises a ConfigurationError' do
        expect { resolver.report_config }.to raise_error(
          UsersReport::ReportConfigResolver::ConfigurationError,
        )
      end
    end

    context 'with a blank issuer' do
      let(:issuer) { nil }

      it 'raises a ConfigurationError' do
        expect { resolver.report_config }.to raise_error(
          UsersReport::ReportConfigResolver::ConfigurationError,
        )
      end
    end
  end

  describe '#agency_abbreviation' do
    context 'with exactly one matching report config' do
      it 'returns the agency abbreviation for that config' do
        expect(resolver.agency_abbreviation).to eq(agency_abbreviation)
      end
    end

    context 'with no unique matching report config' do
      let(:report_configs) { [] }

      it 'returns nil' do
        expect(resolver.agency_abbreviation).to be_nil
      end
    end
  end
end
