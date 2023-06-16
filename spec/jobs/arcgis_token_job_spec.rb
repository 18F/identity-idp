require 'rails_helper'

RSpec.describe ArcgisTokenJob, type: :job do
  let(:token_keeper) { instance_spy(ArcgisApi::TokenKeeper) }
  let(:job) { described_class.new(token_keeper: token_keeper) }
  let(:analytics) { instance_spy(Analytics) }
  describe 'arcgis token job' do
    it 'fetches token successfully' do
      allow(job).to receive(:analytics).and_return(analytics)
      allow(job).to receive(:token_keeper).and_return(token_keeper)
      allow(token_keeper).to receive(:retrieve_token).and_return(ArcgisApi::TokenInfo.new)
      expect(job.perform).to eq(true)
      expect(token_keeper).to have_received(:retrieve_token).once
      expect(token_keeper).to have_received(:save_token).once
      expect(analytics).to have_received(
        :idv_arcgis_token_job_started,
      ).once
      expect(analytics).to have_received(
        :idv_arcgis_token_job_completed,
      ).once
    end
  end
end
