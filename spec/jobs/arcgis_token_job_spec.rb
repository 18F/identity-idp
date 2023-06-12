require 'rails_helper'

RSpec.describe ArcgisTokenJob, type: :job do
  let(:token_keeper) { instance_spy(ArcgisApi::TokenKeeper) }
  let(:subject) { described_class.new(token_keeper: token_keeper) }
  describe 'arcgis token job' do
    it 'fetches token successfully' do
      subject.perform
      expect(token_keeper).to have_received(:retrieve_token).once
    end
  end
end
