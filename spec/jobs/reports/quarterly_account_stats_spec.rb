require 'rails_helper'
require 'csv'

RSpec.describe Reports::QuarterlyAccountStats do
  subject(:report) { described_class.new }

  describe '#perform' do
    let(:end_date) { Time.zone.today }
    let(:ninety_days_ago) { end_date - 90.days }

    it 'saves the report' do
      expect(subject).to receive(:report_body).
        with(ninety_days_ago, end_date).
        and_return('csv text')
      expect(subject).to receive(:save_report).with(
        'quarterly-account-stats',
        'csv text',
        extension: 'csv',
      )
      report.perform(end_date)
    end
  end

  describe '#report_body' do
    subject(:report_body) { report.report_body(start_date, end_date) }

    let(:today) { Time.zone.today }
    let(:start_date) { today - 90.days }
    let(:end_date) { today - 1.day }

    before do
      # These are older than 90 days and should go to grand totals,
      # but not counts for the period.
      travel_to(today - 6.months) do
        create_accounts
      end

      # These are recent and should be included in both the period and
      # grand totals.
      travel_to(today - 1.week) do
        create_accounts
      end

      # This is too new for our interval, so it should only show up in
      # the grand total, and even that's debatable.
      travel_to(today + 1.day) do
        create_accounts
      end
    end

    it 'returns the appropriate counts' do
      row = CSV.parse(report_body, headers: true).first

      aggregate_failures do
        expect(row['start_date']).to eq(start_date.to_s)
        expect(row['end_date']).to eq(end_date.to_s)
        expect(row['deleted_users_all_time']).to eq('3')
        expect(row['deleted_users_for_period']).to eq('1')
        expect(row['users_all_time']).to eq('6')
        expect(row['users_for_period']).to eq('2') # verified + non-verified
        expect(row['users_and_deleted_all_time']).to eq('9')
        expect(row['users_and_deleted_for_period']).to eq('3')
        expect(row['proofed_all_time']).to eq('3')
        expect(row['proofed_for_period']).to eq('1')
      end
    end
  end

  def create_accounts
    create(:user, :proofed) # Proofed user
    create(:user) # Basic user

    # Deleted user:
    user = create(:user)
    DeletedUser.create_from_user(user)
    user.destroy!
  end
end
