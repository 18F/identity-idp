require 'rails_helper'

describe 'GoodJob.cron' do
  it 'has valid cron jobs' do
    expect(Rails.application.config.good_job.cron).to be_present
    aggregate_failures do
      Rails.application.config.good_job.cron.each do |key, config|
        expect(config[:class].constantize.new).to be_kind_of(ApplicationJob)

        expect(Fugit.parse(config[:cron])).to_not be_nil
      end
    end
  end
end
