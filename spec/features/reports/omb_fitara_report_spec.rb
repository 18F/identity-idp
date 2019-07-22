require 'rails_helper'

feature 'OMB Fitara compliance officer runs report' do
  it 'works' do
    visit sign_up_email_path
    sign_up_and_2fa_loa1_user

    results = '{"counts":[{"month":"201907","count":1},{"month":"201906","count":0}]}'
    expect(Reports::OmbFitaraReport.new.call).to eq(results)
  end
end
