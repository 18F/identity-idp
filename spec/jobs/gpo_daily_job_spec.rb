require 'rails_helper'

RSpec.describe GpoDailyJob do
  let(:designated_receiver_pii) do
    {
      first_name: 'Emmy',
      last_name: 'Examperson',
      address1: '123 Main St',
      city: 'Washington',
      state: 'DC',
      zipcode: '20001',
    }
  end

  before do
    allow(IdentityConfig.store).to receive(:gpo_designated_receiver_pii).
      and_return(designated_receiver_pii)
  end

  describe '#perform' do
    subject(:perform) { GpoDailyJob.new.perform(date) }

    context 'on a federal holiday' do
      let(:date) { Date.new(2021, 1, 1) }

      it 'enqueues a test sender' do
        expect { perform }.to change { GpoConfirmation.count }.by(1)
      end

      it 'does not upload to GPO' do
        expect { perform }.to_not change { LetterRequestsToGpoFtpLog.count }
      end
    end

    context 'on a weekday, not a federal holiday' do
      let(:date) { Date.new(2021, 1, 4) }

      it 'enqueues a test sender' do
        # the GpoConfirmation row gets deleted by the uploader job, so we don't have a side
        # effect to test for
        expect(GpoDailyTestSender).to receive(:new).and_call_original

        perform
      end

      it 'uploads to GPO' do
        expect { perform }.to change { LetterRequestsToGpoFtpLog.count }.by(1)
      end
    end
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).to eq("gpo-daily-job-#{date}")
    end
  end
end
