require 'rails_helper'

RSpec.describe 'job_configurations' do
  describe 'weekly report' do
    %w[drop_off_report authentication_report].each do |job_name|
      it "schedules the #{job_name.humanize} to run after the end of the week with yesterday's date" do
        report = GoodJob.configuration.cron[:"weekly_#{job_name}"]
        expect(report[:class]).to eq("Reports::#{job_name.camelize}")

        # Always passes the previous day as the argument
        expect(report[:args].call).to eq([Time.zone.yesterday])

        now = Time.zone.now
        next_time = Fugit.parse(report[:cron]).next_time
        expect(next_time.utc > now.utc.end_of_week).
          to be(true), "Expected #{job_name.humanize} to run after the end of the week"
        expect(next_time.utc).
          to be_within(1).of(now.utc.end_of_week),
             "Expected #{job_name.humanize} to run soon after the end of week, \
             \nso CONUS 'yesterday' and UTC 'yesterday' will never be different"
      end
    end
  end
end
