require 'rails_helper'

RSpec.describe ArcgisTokenJob, type: :job do
  let(:job) { described_class.new }
  let(:geocoder) { instance_double(ArcgisApi::Geocoder) }
  let(:geocoder_factory) { instance_double(ArcgisApi::GeocoderFactory) }
  let(:analytics) { instance_double(Analytics) }
  describe 'arcgis token job' do
    before do
      allow(Analytics).to receive(:new).
        with(
          user: an_instance_of(AnonymousUser),
          request: nil,
          session: {},
          sp: nil,
        ).and_return(analytics)
      allow(ArcgisApi::GeocoderFactory).to receive(:new).and_return(geocoder_factory)
      allow(geocoder_factory).to receive(:create).and_return(geocoder)
    end

    it 'fetches token and logs analytics' do
      expect(analytics).to receive(
        :idv_arcgis_token_job_started,
      ).once
      expect(geocoder).to receive(:retrieve_token!).once
      expect(analytics).to receive(
        :idv_arcgis_token_job_completed,
      ).once
      expect(job.perform).to eq(true)
    end

    context 'geocoder throws error' do
      it 'fetches token and logs analytics' do
        err = RuntimeError.new
        expect(analytics).to receive(
          :idv_arcgis_token_job_started,
        ).once
        expect(geocoder).to receive(:retrieve_token!).and_raise(err).once
        expect(analytics).to receive(
          :idv_arcgis_token_job_completed,
        ).once
        expect do
          job.perform
        end.to raise_error(err)
      end
    end
  end
end
