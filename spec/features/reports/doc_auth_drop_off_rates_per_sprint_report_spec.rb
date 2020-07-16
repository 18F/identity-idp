require 'rails_helper'

feature 'Doc auth drop offs per sprint report' do
  it 'does not throw an error' do
    expect(Reports::DocAuthDropOffRatesPerSprintReport.new.call).to be_present
  end
end
