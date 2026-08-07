require 'rails_helper'

RSpec.describe Proofing::Clear1::Requests::SessionRequest do
  let(:user) { create(:user) }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:project_id) { 'my_project_id' }
  let(:idv_clear1_api_base_url) { 'https://fake-clear1.test' }
  let(:status) { 200 }
  let(:token) { 'fake_token' }
  let(:redirect_url) { 'http://login.test/clear1/session/update' }

  subject(:session_request) do
    described_class.new(redirect_url:)
  end

  before do
    allow(IdentityConfig.store).to receive(:idv_clear1_api_base_url)
      .and_return(idv_clear1_api_base_url)
    allow(IdentityConfig.store).to receive(:idv_clear1_project_id)
      .and_return(project_id)
  end

  describe '#fetch' do
    let(:response)  { session_request.fetch }

    before do
      stub_request(:post, clear_session_endpoint)
        .with(body: {
          project_id:,
          redirect_url:,
        })
        .to_return(
          status:,
          body: {
            token:,
          }.to_json,
        )
    end

    it 'returns a successful response' do
      expect(response.success?).to eq(true)
      expect(response.extra).to include(
        token: 'fake_token',
        vendor_name: Idp::Constants::Vendors::CLEAR1,
      )
    end

    context 'when token is not returned' do
      let(:token) { nil }

      it 'fails with a clear1 error' do
        expect(response.to_h).to include(
          success: false,
          errors: {
            clear1: true,
          },
          vendor_name: Idp::Constants::Vendors::CLEAR1,
          token: nil,
        )
      end
    end

    context 'when Faraday Error' do
      let(:status) { 403 }

      it 'fails with a clear1 error' do
        expect(response.to_h).to include(
          success: false,
          errors: {
            network: true, clear1: true,
         },
          vendor_name: Idp::Constants::Vendors::CLEAR1,
          exception: an_instance_of(Proofing::Clear1::Request::RequestError),
        )
      end
    end

    context 'when Faraday Error' do
      before do
        stub_request(:post, clear_session_endpoint)
          .to_raise(Faraday::ConnectionFailed)
      end

      it 'fails with a network error' do
        expect(response.to_h).to include(
          success: false,
          errors: {
            network: true, clear1: true,
          },
          vendor_name: Idp::Constants::Vendors::CLEAR1,
          exception: an_instance_of(Faraday::ConnectionFailed),
        )
      end
    end
  end
end
