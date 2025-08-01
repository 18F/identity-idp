require 'rails_helper'

RSpec.describe DocAuth::Dos::Requests::HealthCheckRequest do
  include PassportApiHelpers

  def health_check_request_for(endpoint)
    described_class.new(endpoint:)
  end

  let(:analytics) { FakeAnalytics.new }
  let(:step) { 'choose_id_type' }
  let(:context_analytics) { { step: } }

  before do
    stub_health_check_settings
    stub_health_check_endpoints_success
  end

  shared_examples 'a DOS healthcheck endpoint' do |endpoint, success_body|
    describe '#fetch' do
      let(:result) do
        health_check_request_for(endpoint).fetch(analytics, context_analytics: context_analytics)
      end

      describe 'happy path' do
        it 'hits the endpoint' do
          result
          expect(WebMock).to have_requested(:get, endpoint)
        end

        it 'logs the request' do
          result
          expect(analytics).to have_logged_event(
            :passport_api_health_check,
            success: true,
            errors: {},
            step: step,
            body: success_body.to_json,
          )
        end

        describe 'the #fetch result' do
          it 'succeeds' do
            expect(result).to be_success
          end
        end
      end

      context 'when Faraday raises an error' do
        before do
          stub_request(:get, endpoint).to_raise(Faraday::TimeoutError)
        end

        it 'hits the endpoint' do
          result
          expect(WebMock).to have_requested(:get, endpoint)
            .times(IdentityConfig.store.dos_passport_healthcheck_maxretry + 1)
        end

        it 'logs the request' do
          result
          expect(analytics).to have_logged_event(
            :passport_api_health_check,
            hash_including(
              success: false,
              errors: hash_including(
                network: 'faraday exception',
              ),
              step: step,
              exception: a_string_matching(/Faraday::TimeoutError/),
            ),
          )
        end

        describe 'the #fetch result' do
          it 'does not succeed' do
            expect(result).not_to be_success
          end
        end
      end

      [403, 404, 500].each do |status|
        context "when there is an HTTP #{status} error" do
          let(:body) { nil }

          before do
            stub_request(:get, endpoint).to_return(status:, body:)
          end

          it 'hits the endpoint' do
            result
            expect(WebMock).to have_requested(:get, endpoint)
          end

          it 'logs the request' do
            result
            expect(analytics).to have_logged_event(
              :passport_api_health_check,
              hash_including(
                success: false,
                errors: { network: status },
                exception: a_string_matching(/Faraday::/),
              ),
            )
          end

          context 'when there is a response body' do
            let(:body) { '{"error_message" : "all confused"}' }

            it 'includes the body in the event' do
              result
              expect(analytics).to have_logged_event(
                :passport_api_health_check,
                hash_including(
                  success: false,
                  errors: { network: status },
                  exception: a_string_matching(/Faraday::/),
                  body:,
                ),
              )
            end
          end

          describe 'the #fetch result' do
            it 'does not succeed' do
              expect(result).not_to be_success
            end
          end
        end
      end
    end
  end

  describe 'the basic health check endpoint' do
    it_behaves_like 'a DOS healthcheck endpoint',
                    general_health_check_endpoint,
                    successful_api_general_health_check_body
  end

  describe 'the composite health check endpoint' do
    it_behaves_like 'a DOS healthcheck endpoint',
                    composite_health_check_endpoint,
                    successful_api_composite_health_check_body
  end
end
