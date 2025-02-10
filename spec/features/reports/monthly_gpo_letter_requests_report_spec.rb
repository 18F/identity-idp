require 'rails_helper'

RSpec.feature 'Monthly gpo letter requests report' do
  it 'runs when there are not entries' do
    results_hash = JSON.parse(Reports::MonthlyGpoLetterRequestsReport.new.perform(Time.zone.today))
    expect(results_hash['total_letter_requests']).to eq(0)
    expect(results_hash['daily_letter_requests'].count).to eq(0)
  end

  it 'runs when there is one ftp' do
    LetterRequestsToGpoFtpLog.create(ftp_at: Time.zone.now, letter_requests_count: 3)

    results_hash = JSON.parse(Reports::MonthlyGpoLetterRequestsReport.new.perform(Time.zone.today))
    expect(results_hash['total_letter_requests']).to eq(3)
    expect(results_hash['daily_letter_requests'].count).to eq(1)
  end

  it 'totals correctly when there are two ftps' do
    now = Time.zone.now
    LetterRequestsToGpoFtpLog.create(ftp_at: now.yesterday, letter_requests_count: 3)
    LetterRequestsToGpoFtpLog.create(ftp_at: now, letter_requests_count: 4)

    results_hash = JSON.parse(
      Reports::MonthlyGpoLetterRequestsReport.new.perform(
        Time.zone.today,
        start_time: now.yesterday,
        end_time: now.tomorrow,
      ),
    )
    expect(results_hash['total_letter_requests']).to eq(7)
    expect(results_hash['daily_letter_requests'].count).to eq(2)
  end

  it 'only reports on the current month' do
    now = Time.zone.now
    LetterRequestsToGpoFtpLog.create(ftp_at: now - 32.days, letter_requests_count: 3)
    LetterRequestsToGpoFtpLog.create(ftp_at: now, letter_requests_count: 4)

    results_hash = JSON.parse(Reports::MonthlyGpoLetterRequestsReport.new.perform(Time.zone.today))
    expect(results_hash['total_letter_requests']).to eq(4)
    expect(results_hash['daily_letter_requests'].count).to eq(1)
  end
end
