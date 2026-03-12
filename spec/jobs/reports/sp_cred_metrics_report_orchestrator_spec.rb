# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::SpCredMetricsReportOrchestrator do
  let(:perform_date) { Time.zone.parse('2025-09-30 23:59:59 UTC') }
  let(:perform_receiver) { :both }

  subject(:orchestrator) { Reports::SpCredMetricsReportOrchestrator.new }

  let(:config_1) do
    {
      'issuers' => ['issuer1'],
      'partner_strings' => ['Partner_1'],
      'partner_emails' => ['partner1@example.com'],
      'internal_emails' => ['internal1@example.com'],
    }
  end

  let(:config_2) do
    {
      'issuers' => ['issuer2'],
      'partner_strings' => ['Partner_2'],
      'partner_emails' => ['partner2@example.com'],
      'internal_emails' => ['internal2@example.com'],
    }
  end

  let(:configs) { [config_1, config_2] }

  before do
    allow(IdentityConfig.store).to receive(:sp_monthly_cred_metric_report_configs)
      .and_return(configs)
  end

  it 'enqueues one SpCredMetricsReport job per config inside a GoodJob batch' do
    expect(GoodJob::Batch).to receive(:enqueue).and_call_original

    configs.each do |cfg|
      expect(Reports::SpCredMetricsReport).to receive(:perform_later).with(
        perform_date,
        perform_receiver,
        cfg,
      )
    end

    orchestrator.perform(perform_date, perform_receiver)
  end

  context 'when there are no configs' do
    let(:configs) { [] }

    it 'still creates a batch and enqueues no child jobs' do
      expect(GoodJob::Batch).to receive(:enqueue).and_call_original
      expect(Reports::SpCredMetricsReport).not_to receive(:perform_later)

      orchestrator.perform(perform_date, perform_receiver)
    end
  end
end
