require 'rails_helper'

RSpec.describe FrontendLogController do
  describe '.LEGACY_EVENT_MAP' do
    it 'has keys sorted alphabetically' do
      expect(described_class::LEGACY_EVENT_MAP.keys).
        to eq(described_class::LEGACY_EVENT_MAP.keys.sort_by(&:downcase))
    end
  end

  describe '.ALLOWED_EVENTS' do
    it 'is sorted alphabetically' do
      expect(described_class::ALLOWED_EVENTS).to eq(described_class::ALLOWED_EVENTS.sort)
    end
  end

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

      context 'with invalid event name' do
        it 'responds as unsuccessful' do
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
          expect(json[:error_message]).to eq('invalid event')
        end

        it 'does not commit session' do
          action
          expect(request.session_options[:skip]).to eql(true)
        end
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
          let(:payload) do
            { 'selected_location' => selected_location,
              'flow_path' => flow_path,
              'opted_in_to_in_person_proofing' => nil }
          end

          it 'succeeds' do
            action

            expect(fake_analytics).to have_logged_event(
              'IdV: in person proofing location submitted',
              selected_location: selected_location,
              flow_path: flow_path,
              opted_in_to_in_person_proofing: nil,
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
                opted_in_to_in_person_proofing: nil,
              )
            end
          end

          context 'with opt in flag enabled' do
            let(:idv_session) do
              { opt_in_analytics_properties: true }
            end
            let(:payload) do
              { 'selected_location' => selected_location,
                'flow_path' => flow_path,
                'opted_in_to_in_person_proofing' => true }
            end

            before do
              allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).
                and_return(true)
            end

            it 'succeeds' do
              action

              expect(fake_analytics).to have_logged_event(
                'IdV: in person proofing location submitted',
                selected_location: selected_location,
                flow_path: flow_path,
                opted_in_to_in_person_proofing: true,
              )
              expect(response).to have_http_status(:ok)
              expect(json[:success]).to eq(true)
            end
          end
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

        it 'logs the analytics event' do
          action

          expect(fake_analytics).to have_logged_event(
            'IdV: Native camera forced after failed attempts',
            field: field,
            failed_capture_attempts: failed_capture_attempts,
            failed_submission_attempts: failed_submission_attempts,
            flow_path: flow_path,
          )
          expect(response).to have_http_status(:ok)
          expect(json[:success]).to eq(true)
        end
      end

      context 'for an error event' do
        let(:params) do
          {
            'event' => 'Frontend Error',
            'payload' => {
              'name' => 'name',
              'message' => 'message',
              'stack' => 'stack',
              'filename' => 'filename',
            },
          }
        end

        it 'notices the error to NewRelic instead of analytics logger' do
          allow_any_instance_of(FrontendErrorForm).to receive(:submit).
            and_return(FormResponse.new(success: true))
          expect(fake_analytics).not_to receive(:track_event)
          expect(NewRelic::Agent).to receive(:notice_error).with(
            FrontendErrorLogger::FrontendError.new,
            custom_params: {
              frontend_error: {
                name: 'name',
                message: 'message',
                stack: 'stack',
                filename: 'filename',
              },
            },
            expected: true,
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

      context 'with invalid event name' do
        it 'responds as unsuccessful' do
          action

          expect(response).to have_http_status(:bad_request)
          expect(json[:success]).to eq(false)
          expect(json[:error_message]).to eq('invalid event')
        end

        it 'does not commit session' do
          action
          expect(request.session_options[:skip]).to eql(true)
        end
      end
    end
  end
end
