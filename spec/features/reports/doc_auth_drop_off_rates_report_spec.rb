require 'rails_helper'

feature 'Doc auth drop off rates report' do
  it 'does not throw an error' do
    expect(Reports::DocAuthDropOffRatesReport.new.call).to be_present
  end

  it 'has all the steps in the funnel report in the left most column and justified' do
    report = Reports::DocAuthDropOffRatesReport.new.call
    Db::DocAuthLog::DropOffRatesHelper::STEPS.each do |step|
      expect(report.include?(format("\n%20s", step))).to be true
    end
  end
end
