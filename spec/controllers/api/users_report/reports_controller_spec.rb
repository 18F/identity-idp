require 'rails_helper'

RSpec.describe Api::UsersReport::ReportsController do
  include Rails.application.routes.url_helpers

  let(:enabled) { false }
  let(:sp) { create(:service_provider) }
  let(:issuer) { sp.issuer }
  let(:token) { 'a-shared-secret' }
  let(:salt) { SecureRandom.hex(32) }
  let(:cost) { IdentityConfig.store.scrypt_cost }
  let(:auth_header) { "Bearer #{issuer} #{token}" }
  let(:hourstamp) { '2024120915' }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_bucket_name) { 'reports-bucket-test' }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:csv_body) { "uuid,issuer\n123,#{issuer}\n" }
  let(:agency_abbreviation) { 'ABC' }
  let(:expected_key) do
    "test/#{agency_abbreviation.downcase}_proofing_events_by_uuid/2024/2024-12-09.15.csv"
  end

  let(:hashed_token) do
    scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
    scrypted = SCrypt::Engine.hash_secret token, scrypt_salt, 32
    SCrypt::Password.new(scrypted).digest
  end

  let(:users_report_api_config) do
    [
      {
        'agency_abbreviation' => agency_abbreviation,
        'tokens' => [{ 'value' => hashed_token, 'salt' => salt, 'cost' => cost }],
      },
    ]
  end

  let(:report_configs) do
    [
      {
        'issuers' => [issuer, 'urn:example:second-issuer'],
        'agency_abbreviation' => agency_abbreviation,
        'emails' => ['test@example.com'],
      },
    ]
  end

  before do
    stub_analytics
    allow(IdentityConfig.store).to receive(:users_report_api_enabled).and_return(enabled)
    allow(IdentityConfig.store).to receive(:users_report_api_config).and_return(
      users_report_api_config,
    )
    allow(IdentityConfig.store).to receive(:sp_proofing_events_by_uuid_report_configs).and_return(
      report_configs,
    )
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).and_return(
      s3_report_bucket_prefix,
    )
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:bucket_name).with(s3_report_bucket_prefix).and_return(
      s3_bucket_name,
    )
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

    request.headers['Authorization'] = auth_header
  end

  describe '#show' do
    let(:action) { get :show, params: { hourstamp: hourstamp } }

    context 'when the Users Report API is not enabled' do
      it 'returns 404 not found' do
        expect(action.status).to eq(404)
      end
    end

    context 'when the Users Report API is enabled' do
      let(:enabled) { true }

      context 'with no Authorization header' do
        let(:auth_header) { nil }

        it 'returns a 401' do
          expect(action.status).to eq(401)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            hourstamp:,
            success: false,
            status: 401,
            failure_type: :authorization,
          )
        end
      end

      context 'when Authorization header is an empty string' do
        let(:auth_header) { '' }

        it 'returns a 401' do
          expect(action.status).to eq(401)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            hourstamp:,
            success: false,
            status: 401,
            failure_type: :authorization,
          )
        end
      end

      context 'without a Bearer token Authorization header' do
        let(:auth_header) { "#{issuer} #{token}" }

        it 'returns a 401' do
          expect(action.status).to eq(401)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            hourstamp:,
            success: false,
            status: 401,
            failure_type: :authorization,
          )
        end
      end

      context 'with an unknown issuer' do
        let(:issuer) { 'unknown-issuer' }

        it 'returns a 401' do
          expect(action.status).to eq(401)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: false,
            status: 401,
            failure_type: :authorization,
          )
        end
      end

      context 'with an invalid token' do
        let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

        it 'returns a 401' do
          expect(action.status).to eq(401)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: false,
            status: 401,
            failure_type: :authorization,
          )
        end
      end

      context 'with a malformed hourstamp' do
        let(:hourstamp) { '2024-12-09-15' }

        it 'returns a 400 with a JSON error body' do
          expect(action.status).to eq(400)
          expect(response.media_type).to eq('application/json')
          expect(JSON.parse(response.body)).to have_key('error')
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: false,
            status: 400,
            failure_type: :bad_request,
          )
        end
      end

      context 'with an invalid UTC hourstamp' do
        let(:hourstamp) { '2024130925' }

        it 'returns a 400 with a JSON error body' do
          expect(action.status).to eq(400)
          expect(response.media_type).to eq('application/json')
          expect(JSON.parse(response.body)).to have_key('error')
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: false,
            status: 400,
            failure_type: :bad_request,
          )
        end
      end

      context 'when no report config matches the issuer' do
        let(:report_configs) do
          [
            {
              'issuers' => ['urn:example:different-issuer'],
              'agency_abbreviation' => agency_abbreviation,
              'emails' => ['test@example.com'],
            },
          ]
        end

        it 'returns a 500' do
          expect(action.status).to eq(500)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            success: false,
            status: 500,
            failure_type: :server_error,
          )
        end
      end

      context 'when multiple report configs match the issuer' do
        let(:report_configs) do
          [
            {
              'issuers' => [issuer],
              'agency_abbreviation' => 'ABC',
              'emails' => ['test@example.com'],
            },
            {
              'issuers' => [issuer, 'urn:example:other'],
              'agency_abbreviation' => 'DEF',
              'emails' => ['test@example.com'],
            },
          ]
        end

        it 'returns a 500' do
          expect(action.status).to eq(500)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            success: false,
            status: 500,
            failure_type: :server_error,
          )
        end

        context 'and the token is also invalid' do
          let(:auth_header) { "Bearer #{issuer} not-shared-secret" }

          it 'returns a 500 because server misconfiguration takes precedence' do
            expect(action.status).to eq(500)
            expect(@analytics).to have_logged_event(
              :users_report_api_requested,
              issuer:,
              hourstamp:,
              success: false,
              status: 500,
              failure_type: :server_error,
            )
          end
        end
      end

      context 'when the CSV file is not available' do
        before do
          s3_client.stub_responses(
            :get_object,
            lambda do |_context|
              raise Aws::S3::Errors::NoSuchKey.new(nil, nil)
            end,
          )
        end

        it 'returns a 404' do
          expect(action.status).to eq(404)
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: false,
            status: 404,
            failure_type: :not_found,
          )
        end
      end

      context 'when the CSV file is available' do
        before do
          s3_client.stub_responses(
            :get_object,
            { body: StringIO.new(csv_body) },
          )
        end

        it 'returns a 200 with the csv body and attachment headers' do
          expect(action.status).to eq(200)
          expect(response.media_type).to eq('text/csv')
          expect(response.body).to eq(csv_body)
          expect(response.headers['Content-Disposition']).to include('attachment;')
          expect(response.headers['Content-Disposition']).to include('filename=')
          expect(response.headers['Content-Disposition']).to include(
            'abc_proofing_events_by_uuid_2024120915.csv',
          )
          expect(@analytics).to have_logged_event(
            :users_report_api_requested,
            issuer:,
            hourstamp:,
            agency_abbreviation: agency_abbreviation,
            success: true,
            status: 200,
          )
        end

        it 'looks up the stored file for the exact requested hourstamp' do
          action

          expect(s3_client.api_requests).to include(
            a_hash_including(
              operation_name: :get_object,
              params: hash_including(bucket: s3_bucket_name, key: expected_key),
            ),
          )
        end

        it 'matches the report config using the raw header issuer' do
          report_configs.first['issuers'] = [issuer]
          action

          expect(s3_client.api_requests).to include(
            a_hash_including(
              operation_name: :get_object,
              params: hash_including(bucket: s3_bucket_name, key: expected_key),
            ),
          )
        end
      end
    end
  end
end
