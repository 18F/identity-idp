require 'rails_helper'

feature 'Monthly usps letter requests report' do
  it 'runs when there are not entries' do
    results_hash = JSON.parse(Reports::MonthlyUspsLetterRequestsReport.new.call)
    expect(results_hash['total_letter_requests']).to eq(0)
    expect(results_hash['daily_letter_requests'].count).to eq(0)
  end

  it 'runs when there is one ftp' do
    LetterRequestsToUspsFtpLog.create(ftp_at: Time.zone.now, letter_requests_count: 3)

    results_hash = JSON.parse(Reports::MonthlyUspsLetterRequestsReport.new.call)
    expect(results_hash['total_letter_requests']).to eq(3)
    expect(results_hash['daily_letter_requests'].count).to eq(1)
  end

  it 'totals correctly when there are two ftps' do
    now = Time.zone.now
    LetterRequestsToUspsFtpLog.create(ftp_at: now.yesterday, letter_requests_count: 3)
    LetterRequestsToUspsFtpLog.create(ftp_at: now, letter_requests_count: 4)

    results_hash = JSON.parse(Reports::MonthlyUspsLetterRequestsReport.new.call)
    expect(results_hash['total_letter_requests']).to eq(7)
    expect(results_hash['daily_letter_requests'].count).to eq(2)
  end

  it 'only reports on the current month' do
    now = Time.zone.now
    LetterRequestsToUspsFtpLog.create(ftp_at: now - 32.days, letter_requests_count: 3)
    LetterRequestsToUspsFtpLog.create(ftp_at: now, letter_requests_count: 4)

    results_hash = JSON.parse(Reports::MonthlyUspsLetterRequestsReport.new.call)
    expect(results_hash['total_letter_requests']).to eq(4)
    expect(results_hash['daily_letter_requests'].count).to eq(1)
  end
end
