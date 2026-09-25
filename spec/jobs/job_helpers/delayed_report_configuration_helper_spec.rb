# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobHelpers::DelayedReportConfigurationHelper do
  describe '.determine_receiver_for_period_report' do
    context 'with a weekly time frame' do
      # Weeks are Sunday-Saturday. Mar 1-7 2026 is a Sun-Sat week.
      it 'returns :internal while the week is still in progress' do
        # Wed Mar 4, look-back 1 -> anchor Tue Mar 3 -> week ends Sat Mar 7 (future)
        travel_to Time.zone.parse('2026-03-04 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'weekly',
            ),
          ).to eq(:internal)
        end
      end

      it 'returns :both once the week has closed' do
        # Sun Mar 8, look-back 1 -> anchor Sat Mar 7 -> week ended Sat Mar 7
        travel_to Time.zone.parse('2026-03-08 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'weekly',
            ),
          ).to eq(:both)
        end
      end
    end

    context 'with a monthly time frame' do
      it 'returns :internal for a run inside the month it covers' do
        travel_to Time.zone.parse('2026-03-15 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'monthly',
            ),
          ).to eq(:internal)
        end
      end

      it 'returns :both when run on the 1st, covering the closed prior month' do
        travel_to Time.zone.parse('2026-04-01 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'monthly',
            ),
          ).to eq(:both)
        end
      end
    end

    context 'with a quarterly time frame' do
      # The demographics report is the caller that uses this frame, with a
      # 3-day look-back and a 1st-of-month cron.
      it 'returns :internal mid-quarter' do
        travel_to Time.zone.parse('2026-05-04 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 3, time_frame: 'quarterly',
            ),
          ).to eq(:internal)
        end
      end

      it 'returns :both just after a quarter closes' do
        travel_to Time.zone.parse('2026-07-01 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 3, time_frame: 'quarterly',
            ),
          ).to eq(:both)
        end
      end
    end

    context 'with override rules' do
      it 'always returns :internal for always_internal' do
        travel_to Time.zone.parse('2026-04-01 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'monthly',
              external_rule: 'always_internal',
            ),
          ).to eq(:internal)
        end
      end

      it 'always returns :both for always_external' do
        travel_to Time.zone.parse('2026-03-15 12:00:00') do
          expect(
            described_class.determine_receiver_for_period_report(
              run_date: Time.zone.now, lookback_days: 1, time_frame: 'monthly',
              external_rule: 'always_external',
            ),
          ).to eq(:both)
        end
      end

      it 'raises for an unsupported rule' do
        expect {
          described_class.determine_receiver_for_period_report(
            time_frame: 'monthly', external_rule: 'whenever_i_feel_like_it',
          )
        }.to raise_error(ArgumentError, /Unsupported external rule/)
      end
    end

    it 'raises for an unsupported time frame' do
      expect {
        described_class.determine_receiver_for_period_report(time_frame: 'fortnightly')
      }.to raise_error(ArgumentError, /Unsupported time frame/)
    end
  end
end
