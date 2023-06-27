require 'rails_helper'
require 'csv'

RSpec.describe Reports::QuarterlyAccountStats do
  let(:report_date) { Date.new(2020, 1, 1) }

  subject(:report) { described_class.new }

  describe '#perform' do
    # test that it calls save_report
  end

  describe '#report_body' do
    subject(:report_body) { report.report_body(start_date, end_date) }

    let(:start_date) { Time.zone.today - 90.days }
    let(:end_date) { Time.zone.today - 1.day }

    before do
      travel_to(Time.zone.today - 6.months) do
        create_accounts
      end

      travel_to(Time.zone.today - 1.week) do
        create_accounts
      end

      travel_to(Time.zone.today) do
        create_accounts
      end
    end

    it 'does a thing' do
      # convert our CSV to a hash for a more readable test
      lines = CSV.parse(report_body.chomp)
      params = lines[0].zip(lines[1]).to_h

      expected = {
        start_date: start_date.to_s,
        end_date: end_date.to_s,
        deleted_users_all_time: '3',
        deleted_users_for_period: '1',
        users_all_time: '6',
        users_for_period: '2',
        users_and_deleted_all_time: '9',
        users_and_deleted_for_period: '3',
        proofed_all_time: '3',
        proofed_for_period: '1',
      }.stringify_keys
      expect(params).to eq(expected)
    end
  end

  def create_accounts
    create(:user, :proofed) # Proofed user
    create(:user) # Basic user

    # Deleted user:
    user = create(:user)
    DeletedUser.create_from_user(user)
    DeletedUser.find_by(user_id: user.id)
    user.destroy!
  end
end
