require 'rails_helper'

RSpec.describe RemoveOldThrottlesJob do
  let(:limit) { 1 }
  let(:total_limit) { 10 }
  let(:now) { Time.zone.now }

  subject(:job) { RemoveOldThrottlesJob.new }

  describe '#perform' do
    subject(:perform) { job.perform(now, limit: limit, total_limit: total_limit) }

    it 'deletes throttles that are older than WINDOW' do
      old_throttle = create(:throttle, target: SecureRandom.hex, updated_at: now - 45.days)
      new_throttle = create(:throttle, target: SecureRandom.hex, updated_at: now)

      perform

      expect(Throttle.all.map(&:id)).to match_array([new_throttle.id])
    end

    it 'deletes legacy rows with updated_at: nil' do
      legacy_throttle = create(:throttle, target: SecureRandom.hex)
      legacy_throttle.update(updated_at: nil)
      expect(legacy_throttle.reload.updated_at).to be_nil

      expect { perform }.to(change { Throttle.count }.to(0))
    end

    it 'stops after total_limit jobs' do
      (total_limit + 1).times do
        create(:throttle, target: SecureRandom.hex, updated_at: now - 45.days)
      end

      expect { perform }.to(change { Throttle.count }.to(1))
    end
  end

  describe '#good_job_concurrency_key' do
    it 'is the job name and the current time, rounded to the nearest hour' do
      now = Time.zone.at(1629817200)

      job_now = RemoveOldThrottlesJob.new(now)
      expect(job_now.good_job_concurrency_key).to eq("remove-old-throttles-#{now.to_i}")

      job_plus_30m = RemoveOldThrottlesJob.new(now + 30.minutes)
      expect(job_plus_30m.good_job_concurrency_key).to eq(job_now.good_job_concurrency_key)

      job_plus_1h = RemoveOldThrottlesJob.new(now + 1.hour)
      expect(job_plus_1h.good_job_concurrency_key).to_not eq(job_now.good_job_concurrency_key)
    end
  end
end
