# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SocureWebhookController do
  describe 'POST /api/webhooks/socure/event' do
    let(:socure_secret_key) { 'this-is-a-secret' }
    let(:socure_secret_key_queue) { ['this-is-an-old-secret', 'this-is-an-older-secret'] }
    let(:socure_docv_enabled) { true }
    let(:event_type) { 'TEST_WEBHOOK' }
    let(:event_docv_transaction_token) { 'TEST_WEBHOOK_TOKEN' }
    let(:customer_user_id) { '#1-customer' }
    let(:reference_id) { 'the-ref-id' }
    let(:webhook_body) do
      {
        event: {
          created: '2020-01-01T00:00:00Z',
          customerUserId: customer_user_id,
          eventType: event_type,
          docvTransactionToken: event_docv_transaction_token,
          referenceId: reference_id,
          data: {
            documentData: {
              dob: '2000-01-01',
              firstName: 'First',
              lastName: 'Last',
              address: '123 Main St, Baltimore, MD',
            },
          },
        },
      }
    end

    before do
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key).
        and_return(socure_secret_key)
      allow(IdentityConfig.store).to receive(:socure_webhook_secret_key_queue).
        and_return(socure_secret_key_queue)
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).
        and_return(socure_docv_enabled)
      allow(SocureDocvResultsJob).to receive(:perform_later)

      stub_analytics
    end

    context 'webhook authentication' do
      context 'received with invalid webhook key' do
        it 'returns unauthorized with a bad secret key' do
          request.headers['Authorization'] = 'ABC123'
          post :create, params: webhook_body

          expect(response).to have_http_status(:unauthorized)
        end

        it 'returns unauthorized with no secret key' do
          post :create, params: webhook_body

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context 'with a valid webhook key' do
        before do
          request.headers['Authorization'] = socure_secret_key
        end
        it 'returns OK and logs an event with a correct secret key and body' do
          post :create, params: webhook_body

          expect(response).to have_http_status(:ok)
          expect(@analytics).to have_logged_event(
            :idv_doc_auth_socure_webhook_received,
            created_at: '2020-01-01T00:00:00Z',
            customer_user_id:,
            docv_transaction_token: event_docv_transaction_token,
            event_type:,
            reference_id:,
          )
        end

        it 'returns OK with an older secret key' do
          request.headers['Authorization'] = socure_secret_key_queue.last
          post :create, params: webhook_body

          expect(response).to have_http_status(:ok)
        end

        context 'when an event does not exist in the body' do
          it 'returns bad request' do
            post :create, params: {}

            expect(response).to have_http_status(:bad_request)
          end
        end

        context 'when document capture session exists' do
          it 'logs the user\'s uuid' do
            dcs = create(:document_capture_session, :socure)
            webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token
            post :create, params: webhook_body

            expect(response).to have_http_status(:ok)
            expect(@analytics).to have_logged_event(
              :idv_doc_auth_socure_webhook_received,
              created_at: '2020-01-01T00:00:00Z',
              customer_user_id:,
              docv_transaction_token: dcs.socure_docv_transaction_token,
              event_type:,
              reference_id:,
              user_id: dcs.user.uuid,
            )
          end

          context 'when DOCUMENTS_UPLOADED event received' do
            let(:event_type) { 'DOCUMENTS_UPLOADED' }

            it 'returns OK and logs an event with a correct secret key and body' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              post :create, params: webhook_body
              expect(response).to have_http_status(:ok)
              expect(@analytics).to have_logged_event(
                :idv_doc_auth_socure_webhook_received,
                created_at: webhook_body[:event][:created],
                customer_user_id:,
                docv_transaction_token: dcs.socure_docv_transaction_token,
                event_type:,
                reference_id:,
                user_id: dcs.user.uuid,
              )
            end

            it 'increments rate limiter of correct user' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              i = 0
              while i < 4
                rate_limiter = RateLimiter.new(
                  user: dcs.user,
                  rate_limit_type: :idv_doc_auth,
                )
                expect(rate_limiter.attempts).to eq i
                i += 1
                post :create, params: webhook_body
              end
            end

            it 'enqueues a SocureDocvResultsJob' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              post :create, params: webhook_body

              expect(SocureDocvResultsJob).to have_received(:perform_later).
                with(document_capture_session_uuid: dcs.uuid)
            end

            it 'does not reset socure_docv_capture_app_url value' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token
              post :create, params: webhook_body
              dcs.reload
              expect(dcs.socure_docv_capture_app_url).not_to be_nil
            end

            context 'when document capture session does not exist' do
              before do
                allow(NewRelic::Agent).to receive(:notice_error)
              end

              it 'logs an error with NewRelic' do
                request.headers['Authorization'] = socure_secret_key_queue.last
                post :create, params: webhook_body

                expect(NewRelic::Agent).to have_received(:notice_error)
              end
            end
          end

          context 'when SESSION_COMPLETE event received' do
            let(:event_type) { 'SESSION_COMPLETE' }

            it 'does not increment rate limiter of user' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              i = 0
              while i < 4
                post :create, params: webhook_body
                rate_limiter = RateLimiter.new(
                  user: dcs.user,
                  rate_limit_type: :idv_doc_auth,
                )
                expect(rate_limiter.attempts).to eq 0
                i += 1
              end
            end

            it 'does not enqueue a SocureDocvResultsJob' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              post :create, params: webhook_body

              expect(SocureDocvResultsJob).not_to have_received(:perform_later)
            end

            it 'resets socure_docv_capture_app_url to nil' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token
              expect(dcs.socure_docv_capture_app_url).
                not_to be_nil
              post :create, params: webhook_body
              dcs.reload
              expect(dcs.socure_docv_capture_app_url).to be_nil
            end
          end

          context 'when SESSION_EXPIRED event received' do
            let(:event_type) { 'SESSION_EXPIRED' }

            it 'does not increment rate limiter of user' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              i = 0
              while i < 4
                post :create, params: webhook_body

                rate_limiter = RateLimiter.new(
                  user: dcs.user,
                  rate_limit_type: :idv_doc_auth,
                )
                expect(rate_limiter.attempts).to eq 0
                i += 1
              end
            end

            it 'does not enqueue a SocureDocvResultsJob' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token

              post :create, params: webhook_body

              expect(SocureDocvResultsJob).not_to have_received(:perform_later)
            end

            it 'resets socure_docv_capture_app_url to nil' do
              dcs = create(:document_capture_session, :socure)
              webhook_body[:event][:docvTransactionToken] = dcs.socure_docv_transaction_token
              expect(dcs.socure_docv_capture_app_url).
                not_to be_nil
              post :create, params: webhook_body
              dcs.reload
              expect(dcs.socure_docv_capture_app_url).to be_nil
            end
          end

          context 'when socure webhook disabled' do
            let(:socure_docv_enabled) { false }

            it 'the webhook route does not exist' do
              post :create, params: webhook_body

              expect(response).to be_not_found
            end
          end
        end
      end
    end
  end
end
