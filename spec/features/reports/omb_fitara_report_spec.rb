require 'rails_helper'

feature 'OMB Fitara compliance officer runs report' do
  it 'works in july' do
    Timecop.travel Date.new(2019, 7, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201907","count":1},{"month":"201906","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end

  it 'works in december' do
    Timecop.travel Date.new(2019, 12, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201912","count":1},{"month":"201911","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end

  it 'works in january' do
    Timecop.travel Date.new(2019, 1, 2) do
      visit sign_up_email_path
      sign_up_and_2fa_loa1_user

      results = '{"counts":[{"month":"201901","count":1},{"month":"201812","count":0}]}'
      expect(Reports::OmbFitaraReport.new.call).to eq(results)
    end
  end
end
