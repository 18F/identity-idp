require 'rails_helper'

RSpec.describe ArcgisTokenJob, type: :job do
  let(:subject) { described_class.new }
  describe 'arcgis token job' do
    before(:each) do
      subject.token_keeper.remove_token!
    end
    after(:each) do
      subject.token_keeper.remove_token!
    end
    it 'fetches token successfully' do
      expected = 'ABCDEFG'
      stub_request(:post, %r{/generateToken}).to_return(
        {
          status: 429,
        },
        {
          status: 403,
        },
        {
          status: 200,
          body: ArcgisApi::Mock::Fixtures.request_token_service_error,
          headers: { content_type: 'application/json;charset=UTF-8' },
        },
        {
          status: 200,
          body: ArcgisApi::Mock::Fixtures.invalid_gis_token_credentials_response,
          headers: { content_type: 'application/json;charset=UTF-8' },
        },
        { status: 200,
          body: {
            token: expected,
            expires: (Time.zone.now.to_f + 3600) * 1000,
            ssl: true,
          }.to_json,
          headers: { content_type: 'application/json;charset=UTF-8' } },
      )
      subject.perform
    end
  end
end
