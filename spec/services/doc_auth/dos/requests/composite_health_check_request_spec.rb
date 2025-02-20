require 'rails_helper'

RSpec.describe DocAuth::Dos::Requests::CompositeHealthCheckRequest do
  include PassportApiHelpers

  subject(:health_check_request) { described_class.new }

  let(:analytics) { FakeAnalytics.new }

  let(:health_check_endpoint) { 'https://composite-health-check.passports-api.test.org' }

  before do
    allow(IdentityConfig.store).to(
      receive(:dos_passport_composite_healthcheck_endpoint),
    ).and_return(health_check_endpoint)
  end

  describe '#fetch' do
    let(:result) { health_check_request.fetch(analytics) }

    context 'happy path' do
      let(:successful_api_health_check_body) do
        {
          name: 'Passport Match Process API',
          status: 'Up',
          environment: 'dev-share',
          comments: 'Ok',
        }
      end

      before do
        stub_request(:get, health_check_endpoint)
          .to_return_json(
            body: successful_api_health_check_body,
          )
      end

      it 'hits the endpoint' do
        result
        expect(WebMock).to have_requested(:get, health_check_endpoint)
      end

      it 'logs the request' do
        result
        expect(analytics).to have_logged_event(
          :passport_api_health_check,
          success: true,
          body: successful_api_health_check_body.to_json,
        )
      end

      describe 'the #fetch result' do
        it 'succeeds' do
          expect(result).to be_success
        end
      end
    end

    [403, 404, 500].each do |status|
      context "when there is an HTTP #{status} error" do
        before do
          stub_request(:get, health_check_endpoint).to_return(status:)
        end

        it 'hits the endpoint' do
          result
          expect(WebMock).to have_requested(:get, health_check_endpoint)
        end

        # TODO: add more analytics arguments.
        it 'logs the request' do
          result
          expect(analytics).to have_logged_event(
            :passport_api_health_check,
            hash_including(success: false)
          )
        end

        describe 'the #fetch result' do
          it 'does not succeed' do
            expect(result).not_to be_success
          end
        end
      end
    end

    context 'when Faraday throws an error' do
      before do
        stub_request(:get, health_check_endpoint).to_raise(Faraday::Error)
      end

      it 'hits the endpoint' do
        result
        expect(WebMock).to have_requested(:get, health_check_endpoint)
      end

      it 'logs the request' do
        result
        expect(analytics).to have_logged_event(
          :passport_api_health_check,
          hash_including(success: false),
        )
      end

      describe 'the #fetch result' do
        it 'does not succeed' do
          expect(result).not_to be_success
        end
      end
    end
  end
end
