require 'rails_helper'

RSpec.describe 'GoodJob.cron' do
  it 'has valid cron jobs' do
    expect(Rails.application.config.good_job.cron).to be_present
    aggregate_failures do
      Rails.application.config.good_job.cron.each do |_key, config|
        expect(config[:class].constantize.new).to be_kind_of(ApplicationJob)

        expect(Fugit.parse(config[:cron])).to_not be_nil
      end
    end
  end

  describe 'weekly reporting' do
    %w[drop_off_report authentication_report].each do |job_name|
      it "schedules the #{job_name} to run after the end of the week with yesterday's date" do
        report = GoodJob.configuration.cron[:"weekly_#{job_name}"]
        expect(report[:class]).to eq("Reports::#{job_name.camelize}")

        freeze_time do
          # Always passes the previous day as the argument
          # Our CloudwatchClient requires using DateTime. It won't accept a Date without coercion
          expect(report[:args].call).to eq([Time.zone.yesterday.end_of_day])

          now = Time.zone.now
          next_time = Fugit.parse(report[:cron]).next_time
          expect(next_time.utc > now.utc.end_of_week).
            to be(true), "Expected #{job_name} to next run after the end of this week"
          expect(next_time.utc).
            to be_within(1).of(now.utc.end_of_week), <<~EOS.squish
              Expected #{job_name} to run soon after the end of week,
              so CONUS 'yesterday' and UTC 'yesterday' will never be different
            EOS
        end
      end
    end
  end
end
