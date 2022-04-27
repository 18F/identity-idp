require 'rails_helper'

RSpec.describe PhoneNumberOptOutSyncJob do
  describe '#perform' do
    include_context 'telephony'

    let(:phone1) { Faker::PhoneNumber.cell_phone }
    let(:phone2) { Faker::PhoneNumber.cell_phone }
    let(:phone3) { Faker::PhoneNumber.cell_phone }

    before do
      Aws.config[:sns] = {
        stub_responses: {
          list_phone_numbers_opted_out: [
            {
              phone_numbers: [phone1, phone2],
              next_token: SecureRandom.hex,
            },
            {
              phone_numbers: [phone3],
            },
          ],
        },
      }
    end

    it 'adds phone numbers that are opted out in AWS to the database' do
      PhoneNumberOptOutSyncJob.new.perform(Time.zone.now)

      [phone1, phone2, phone3].each do |phone|
        expect(PhoneNumberOptOut.find_with_phone(phone)).to be_present
      end
    end
  end

  describe '#good_job_concurrency_key' do
    it 'is the job name and the current time, rounded to the nearest hour' do
      now = Time.zone.at(1629817200)

      job_now = PhoneNumberOptOutSyncJob.new(now)
      expect(job_now.good_job_concurrency_key).to eq("phone-number-opt-out-sync-#{now.to_i}")

      job_plus_30m = PhoneNumberOptOutSyncJob.new(now + 30.minutes)
      expect(job_plus_30m.good_job_concurrency_key).to eq(job_now.good_job_concurrency_key)

      job_plus_1h = PhoneNumberOptOutSyncJob.new(now + 1.hour)
      expect(job_plus_1h.good_job_concurrency_key).to_not eq(job_now.good_job_concurrency_key)
    end
  end
end
