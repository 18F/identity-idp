require 'rails_helper'

RSpec.describe Api::IrsAttemptsApiController do
  before do
    stub_analytics

    allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(false)
    allow(IdentityConfig.store).to receive(:irs_attempt_api_auth_tokens).
      and_return(valid_auth_tokens.map { |t| OpenSSL::Digest::SHA256.hexdigest(t) })

    existing_events

    request.headers['Authorization'] =
      "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"
  end
  let(:time) { Time.new(2022, 1, 1, 0, 0, 0, 'Z') }

  let(:valid_auth_tokens) { 3.times.map { SecureRandom.hex } }
  let(:auth_token) { valid_auth_tokens.first }

  let(:existing_events) do
    3.times.map do
      event = IrsAttemptsApi::AttemptEvent.new(
        event_type: :test_event,
        session_id: 'test-session-id',
        occurred_at: time,
        event_metadata: {
          first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
        },
      )
      jti = event.jti
      jwe = event.to_jwe
      event_key = event.event_key
      IrsAttemptsApi::RedisClient.new.write_event(
        event_key: event_key,
        jwe: jwe,
        timestamp: event.occurred_at,
      )
      [jti, jwe]
    end
  end
  let(:existing_event_jtis) { existing_events.map(&:first) }

  describe '#create' do
    let(:test_object) { '{test: "test"}' }
    before do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: { body: test_object },
        },
      }
    end

    context 'with aws_s3 enabled' do
      let(:wrong_time) { time - 1.year }
      let(:timestamp) { '2022-11-08T18:00:00.000Z' }

      before do
        allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_enabled).and_return(true)

        IrsAttemptApiLogFile.create(
          filename: 'test_filename',
          iv: Base64.strict_encode64('test_iv'),
          encrypted_key: Base64.strict_encode64('test_encrypted_key'),
          requested_time: IrsAttemptsApi::EnvelopeEncryptor.formatted_timestamp(time),
        )
      end

      it 'should return 404 when file not found' do
        post :create, params: { timestamp: wrong_time.iso8601 }

        expect(response.status).to eq(404)
      end

      it 'should render data from s3 correctly' do
        post :create, params: { timestamp: time.iso8601 }

        expect(response).to be_ok
        expect(Base64.strict_decode64(response.headers['X-Payload-IV'])).to be_present
        expect(Base64.strict_decode64(response.headers['X-Payload-Key'])).to be_present
        expect(response.body).to eq(test_object)
      end

      context 'with aws_s3_stream enabled' do
        let(:test_object) { '{test: "1234567890 12345"}' }
        before do
          allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_stream_enabled).
            and_return(true)
          allow(IdentityConfig.store).to receive(:irs_attempt_api_aws_s3_stream_buffer_size).
            and_return(10)

          Aws.config[:s3] = {
            stub_responses: {
              head_object: { content_length: test_object.bytesize },
              get_object: proc do |context|
                range_string = context.params[:range]
                _, byte_string = range_string.split('=')
                start_byte, _ = byte_string.split('-')
                { body: test_object.byteslice(
                  start_byte.to_i,
                  IdentityConfig.store.irs_attempt_api_aws_s3_stream_buffer_size + 1,
                ) }
              end,
            },
          }
        end

        it 'should render data streamed from s3 correctly' do
          post :create, params: { timestamp: time.iso8601 }

          expect(response).to be_ok
          expect(Base64.strict_decode64(response.headers['X-Payload-IV'])).to be_present
          expect(Base64.strict_decode64(response.headers['X-Payload-Key'])).to be_present
          expect(response.content_type).to eq('application/octet-stream')
          expect(response['Content-Disposition']).
            to eq("attachment; filename=\"test_filename\"; filename*=UTF-8''test_filename")

          expect(response.stream.body).to eq(test_object)
        end
      end
    end

    context 'with timestamp problems' do
      it 'returns unprocessable_entity when given no timestamp' do
        post :create, params: { timestamp: nil }

        expect(response.status).to eq(422)
      end

      it 'returns unprocessable_entity when timestamp is invalid' do
        post :create, params: { timestamp: 'INVALID*TIME' }

        expect(response.status).to eq(422)
      end
    end

    context 'with aws_s3 disabled' do
      let(:timestamp) { '2022-11-08T18:00:00.000Z' }
      it 'should bypass s3 retrieval' do
        expect_any_instance_of(Aws::S3::Client).not_to receive(:get_object)

        post :create, params: { timestamp: timestamp }

        expect(response).to be_ok
        expect(Base64.strict_decode64(response.headers['X-Payload-IV'])).to be_present
        expect(Base64.strict_decode64(response.headers['X-Payload-Key'])).to be_present
        expect(Base64.strict_decode64(response.body)).to be_present
      end
    end

    context 'with CSRF protection enabled' do
      around do |ex|
        ActionController::Base.allow_forgery_protection = true
        ex.run
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it 'allows authentication without error' do
        request.headers['Authorization'] =
          "Bearer #{IdentityConfig.store.irs_attempt_api_csp_id} #{auth_token}"

        post :create, params: { timestamp: time.iso8601 }

        expect(response.status).to eq(200)
      end
    end

    context 'with a timestamp including a fractional second' do
      let(:timestamp) { '2022-11-08T18:00:00.000Z' }

      it 'accepts the timestamp as valid' do
        post :create, params: { timestamp: timestamp }
        expect(response.status).to eq(200)
      end
    end

    it 'renders a 404 if disabled' do
      allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(false)

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(404)
    end

    it 'returns an error when required timestamp parameter is missing' do
      post :create, params: {}
      expect(response.status).to eq 422
    end

    it 'returns an error when timestamp parameter is empty' do
      post :create, params: { timestamp: '' }
      expect(response.status).to eq 422
    end

    it 'returns an error when timestamp parameter is invalid' do
      post :create, params: { timestamp: 'abc' }
      expect(response.status).to eq 422

      post :create, params: { timestamp: 'T14' }
      expect(response.status).to eq 422
    end

    it 'authenticates the client' do
      request.headers['Authorization'] = auth_token # Missing Bearer prefix

      post :create, params: { timestamp: time.iso8601 }
      expect(@analytics).to have_logged_event(
        'IRS Attempt API: Events submitted',
        rendered_event_count: 3,
        authenticated: false,
        elapsed_time: 0,
        success: false,
        timestamp: time.iso8601,
      )

      expect(response.status).to eq(401)

      request.headers['Authorization'] = 'garbage-fake-token-nobody-likes'

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(401)

      request.headers['Authorization'] = nil

      post :create, params: { timestamp: time.iso8601 }

      expect(response.status).to eq(401)
    end

    it 'renders encrypted events' do
      allow_any_instance_of(described_class).to receive(:elapsed_time).and_return(0.1234)

      post :create, params: { timestamp: time.iso8601 }

      expect(response).to be_ok
      expect(Base64.strict_decode64(response.headers['X-Payload-IV'])).to be_present
      expect(Base64.strict_decode64(response.headers['X-Payload-Key'])).to be_present
      expect(Base64.strict_decode64(response.body)).to be_present

      expect(@analytics).to have_logged_event(
        'IRS Attempt API: Events submitted',
        rendered_event_count: existing_events.count,
        authenticated: true,
        elapsed_time: 0.1234,
        success: true,
        timestamp: time.iso8601,
      )
    end
  end
end
