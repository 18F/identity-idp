require 'rails_helper'

RSpec.describe JobHelpers::JobConfigurationHelper do
  describe '.report_receiver_based_on_cadence' do
    subject(:receiver) { described_class.report_receiver_based_on_cadence(report_date, cadence) }

    context 'monthly cadence' do
      let(:cadence) { :monthly }

      it 'return :both on the last day of month' do
        report_date = Time.zone.parse('2025-09-30')
        expect(
          described_class.report_receiver_based_on_cadence(
            report_date,
            cadence,
          ),
        ).to eq(:both)
      end

      it 'return :internal when it is not last day of the month' do
        report_date = Time.zone.parse('2025-09-27')
        expect(
          described_class.report_receiver_based_on_cadence(
            report_date,
            cadence,
          ),
        ).to eq(:internal)
      end
    end

    context 'quarterly cadence' do
      let(:cadence) { :quarterly }

      it 'return :both on quarter end (Mar 31)' do
        report_date = Time.zone.parse('2025-03-31')
        expect(
          described_class.report_receiver_based_on_cadence(
            report_date,
            cadence,
          ),
        ).to eq(:both)
      end

      it 'return :both on quarter end (June 30)' do
        report_date = Time.zone.parse('2025-06-30')
        expect(
          described_class.report_receiver_based_on_cadence(
            report_date,
            cadence,
          ),
        ).to eq(:both)
      end

      it 'return :internal on non-quarter-end (July 30)' do
        report_date = Time.zone.parse('2025-07-30')
        expect(
          described_class.report_receiver_based_on_cadence(
            report_date,
            cadence,
          ),
        ).to eq(:internal)
      end
    end

    context 'default behaviour' do
      include ActiveSupport::Testing::TimeHelpers

      it 'default to yesterday end_of_day and monthly cadence' do
        travel_to Time.zone.parse('2025-08-25') do
          expect(
            described_class.report_receiver_based_on_cadence,
          ).to eq(:internal)
        end
      end
    end
  end

  describe '.build_irs_report_args' do
    subject(:args) do
      described_class.build_irs_report_args(report_date, cadence)
    end

    context 'monthly cadence' do
      let(:cadence) { :monthly }
      it 'return [report_date,:both] for month end Sep 30' do
        report_date = Time.zone.parse('2025-09-30')
        expect(
          described_class.build_irs_report_args(
            report_date,
            cadence,
          ),
        ).to eq([report_date, :both])
      end
    end

    context 'quarterly cadence' do
      let(:cadence) { :quarterly }
      it 'return [report_date,:both] for month end Dec 31' do
        report_date = Time.zone.parse('2025-12-31')
        expect(
          described_class.build_irs_report_args(
            report_date,
            cadence,
          ),
        ).to eq([report_date, :both])
      end
    end

    context 'default behaviour' do
      include ActiveSupport::Testing::TimeHelpers

      it 'default to yesterday end_of_day and monthly cadence' do
        report_date = Time.zone.parse('2025-08-25').yesterday.end_of_day
        travel_to Time.zone.parse('2025-08-25') do
          expect(
            described_class.build_irs_report_args,
          ).to eq([report_date, :internal])
        end
      end
    end
  end
end
