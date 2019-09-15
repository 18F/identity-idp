require 'rails_helper'

feature 'scheduler runs report' do
  it 'works for no users' do
    expect(Reports::SpSuccessRateReport.new.call).to eq([].to_json)
  end
end
