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
        allow(controller).to receive(:analytics).and_return(fake_analytics)
      end

      it 'succeeds' do
        expect(fake_analytics).to receive(:track_event).
          with("Frontend: #{event}", payload)

        action

        expect(response).to have_http_status(:ok)
        expect(json[:success]).to eq(true)
      end

      context 'allowlisted analytics event' do
        let(:event) { 'IdV: download personal key' }

        it 'succeeds' do
          action

          expect(fake_analytics).to have_logged_event('IdV: personal key downloaded')
          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end

        context 'with payload' do
          let(:selected_location) { 'Bethesda' }
          let(:flow_path) { 'standard' }
          let(:event) { 'IdV: location submitted' }
          let(:payload) { { 'selected_location' => selected_location, 'flow_path' => flow_path } }

          it 'succeeds' do
            action

            expect(fake_analytics).to have_logged_event(
              'IdV: in person proofing location submitted',
              selected_location: selected_location,
              flow_path: flow_path,
            )
            expect(response).to have_http_status(:ok)
            expect(json[:success]).to eq(true)
          end

          context 'with missing keyword arguments' do
            let(:payload) { {} }

            it 'gracefully sets the missing values to nil' do
              action

              expect(fake_analytics).to have_logged_event(
                'IdV: in person proofing location submitted',
                flow_path: nil,
                selected_location: nil,
              )
            end
          end
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
        let(:field) { 'front' }
        let(:failed_capture_attempts) { 0 }
        let(:failed_submission_attempts) { 0 }
        let(:flow_path) { 'standard' }
        let(:params) do
          {
            'event' => 'IdV: Native camera forced after failed attempts',
            'payload' => {
              'field' => field,
              'failed_capture_attempts' => failed_capture_attempts,
              'failed_submission_attempts' => failed_submission_attempts,
              'flow_path' => flow_path,
            },
          }
        end

        it 'logs the analytics event without the prefix' do
          expect(fake_analytics).to receive(:track_event).with(
            'IdV: Native camera forced after failed attempts',
            field: field,
            failed_capture_attempts: failed_capture_attempts,
            failed_submission_attempts: failed_submission_attempts,
            flow_path: flow_path,
          )

          action

          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
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
