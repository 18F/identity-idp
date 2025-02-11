require 'rails_helper'
require 'reporting/ab_tests_report'

RSpec.describe Reporting::AbTestsReport do
  let(:time_range) { Date.new(2025, 1, 1).all_day }
  let(:options) { {} }
  let(:ab_test_options) { {} }

  subject(:report) do
    Reporting::AbTestsReport.new(
      ab_test: AbTest.new(
        experiment_name: 'reCAPTCHA at Sign-In',
        report: {
          email: 'email@example.com',
          queries: [
            {
              title: 'Sign in success rate by CAPTCHA validation performed',
              query: <<~QUERY,
                fields properties.event_properties.captcha_validation_performed as `Captcha Validation Performed`
                | filter name = 'Email and Password Authentication'
                | stats avg(properties.event_properties.success)*100 as `Success Percent` by `Captcha Validation Performed`
                | sort `Captcha Validation Performed` asc
              QUERY
              row_labels: ['Validation Not Performed', 'Validation Performed'],
            },
          ],
        },
        **ab_test_options,
      ),
      time_range:,
      **options,
    )
  end

  before do
    stub_cloudwatch_logs(
      [
        { 'Captcha Validation Performed' => '0', 'Success Percent' => '90.18501' },
        { 'Captcha Validation Performed' => '1', 'Success Percent' => '85.68103' },
      ],
    )
  end

  describe '#as_tables' do
    subject(:tables) { report.as_tables }

    it 'generates the tabular data' do
      expect(tables).to eq(
        [
          [
            ['Captcha Validation Performed', 'Success Percent'],
            ['Validation Not Performed', '90.19%'],
            ['Validation Performed', '85.68%'],
          ],
        ],
      )
    end
  end

  describe '#as_emailable_reports' do
    subject(:emailable_reports) { report.as_emailable_reports }

    it 'adds a "first row" hash with a title for tables_report mailer' do
      aggregate_failures do
        emailable_reports.each do |emailable_report|
          expect(emailable_report.title).to be_present
        end
      end
    end
  end

  describe '#participants_message' do
    subject(:participants_message) { report.participants_message }

    context 'with unpersisted ab test' do
      it { is_expected.to be_nil }
    end

    context 'with persisted ab test' do
      let(:ab_test_options) { super().merge(persist: true) }

      it 'returns message with number of participants' do
        expect(participants_message).to eq('Total participants: 0')
      end

      context 'with maximum participant ab test' do
        let(:ab_test_options) { super().merge(max_participants: 10_000) }

        it 'returns message with number of participants and maximum' do
          expect(participants_message).to eq('Total participants: 0 (of 10,000 maximum)')
        end
      end
    end
  end
end
