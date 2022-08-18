require 'rails_helper'

describe FrontendLogController do
  describe '#create' do
    subject(:action) { post :create, params: params, as: :json }

    let(:fake_analytics) { FakeAnalytics.new }
    let(:user) { create(:user, :with_phone, with: { phone: '+1 (202) 555-1212' }) }
    let(:event) { 'Custom Event' }
    let(:payload) { { 'message' => 'To be logged...' } }
    let(:params) { { 'event' => event, 'payload' => payload } }
    let(:json) { JSON.parse(response.body, symbolize_names: true) }

    context 'user is signed in' do
      before do
        sign_in user
        allow(Analytics).to receive(:new).and_return(fake_analytics)
      end

      it 'succeeds' do
        expect(fake_analytics).to receive(:track_event).
          with("Frontend: #{event}", payload)

        action

        expect(response).to have_http_status(:ok)
        expect(json[:success]).to eq(true)
      end

      context 'allowlisted analytics event' do
        let(:event) { 'IdV: personal key visited' }

        it 'succeeds' do
          action

          expect(fake_analytics).to have_logged_event('IdV: personal key visited')
          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
      end

      context 'allowlisted analytics event with compound proc' do
        let(:event) { 'IdV: password confirm submitted' }

        it 'succeeds' do
          action

          expect(fake_analytics).to have_logged_event('IdV: review complete')
          expect(fake_analytics).to have_logged_event('IdV: final resolution', success: true)
          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
      end

      context 'empty payload' do
        let(:payload) { {} }

        it 'succeeds' do
          expect(fake_analytics).to receive(:track_event).
            with("Frontend: #{event}", payload)

          action

          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
      end

      context 'invalid param' do
        it 'rejects a non-hash payload' do
          expect(fake_analytics).not_to receive(:track_event)

          params[:payload] = 'abc'
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end

        it 'rejects a non-string event' do
          expect(fake_analytics).not_to receive(:track_event)

          params[:event] = { abc: 'abc' }
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end
      end

      context 'missing a parameter' do
        it 'rejects a request without specifying event' do
          expect(fake_analytics).not_to receive(:track_event)

          params.delete('event')
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end

        it 'rejects a request without specifying payload' do
          expect(fake_analytics).not_to receive(:track_event)

          params.delete('payload')
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
        end
      end

      context 'for a named analytics method' do
        let(:payload) { { 'field' => 'front', 'failed_attempts' => 0 } }
        let(:params) do
          {
            'event' => 'IdV: Native camera forced after failed attempts',
            'payload' => payload,
          }
        end

        it 'logs the analytics event without the prefix' do
          expect(fake_analytics).to receive(:track_event).with(
            'IdV: Native camera forced after failed attempts', payload
          )

          action

          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
      end
    end

    context 'user is not signed in' do
      it 'returns unauthorized' do
        allow(Analytics).to receive(:new).and_return(fake_analytics)

        expect(fake_analytics).not_to receive(:track_event)

        action

        expect(response).to have_http_status(:unauthorized)
        expect(json[:success]).to eq(false)
      end
    end

    context 'anonymous user with session-associated user id' do
      let(:user_id) { user.id }

      before do
        session[:doc_capture_user_id] = user_id
        allow(Analytics).to receive(:new).and_return(fake_analytics)
        expect(Analytics).to receive(:new).with(hash_including(user: user))
      end

      it 'succeeds' do
        expect(fake_analytics).to receive(:track_event).with("Frontend: #{event}", payload)

        action

        expect(response).to have_http_status(:ok)
        expect(json[:success]).to eq(true)
      end
    end
  end
end
