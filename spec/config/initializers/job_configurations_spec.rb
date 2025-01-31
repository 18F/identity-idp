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

  it 'has a consistent class name' do
    aggregate_failures do
      Rails.application.config.good_job.cron.each do |_key, config|
        expect(config[:class]).to match(/Job\z|Report/)
      end
    end
  end

  describe 'weekly reporting' do
    %w[drop_off_report authentication_report protocols_report].each do |job_name|
      it "schedules the #{job_name} to run after the end of the week with yesterday's date" do
        report = GoodJob.configuration.cron[:"weekly_#{job_name}"]
        expect(report).to be, "Missing report weekly_#{job_name}"
        expect(report[:class]).to eq("Reports::#{job_name.camelize}")

        freeze_time do
          # Always passes the previous day as the argument
          # Our CloudwatchClient requires using DateTime. It won't accept a Date without coercion
          expect(report[:args].call).to eq([Time.zone.yesterday.end_of_day])

          now = Time.zone.now
          next_time = Fugit.parse(report[:cron]).next_time
          expect(next_time.utc)
            .to be_within(2.hours + 1.minute).of(now.utc.end_of_week)
          expect(next_time.utc).to be > now.utc.end_of_week
        end
      end
    end
    it 'has each report scheduled at a different time' do
      next_times = freeze_time do
        %w[drop_off_report authentication_report protocols_report].map do |job_name|
          report = GoodJob.configuration.cron[:"weekly_#{job_name}"]
          expect(report).to be, "Missing report weekly_#{job_name}"
          expect(report[:class]).to eq("Reports::#{job_name.camelize}")
          expect(report[:args].call).to eq([Time.zone.yesterday.end_of_day])
          Fugit.parse(report[:cron]).next_time.to_i
        end
      end
      expect(next_times.count).to be(3)
      expect(next_times.uniq.count).to be(3)
    end
  end
end
