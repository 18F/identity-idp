require 'rails_helper'

RSpec.describe FraudOpsS3BatchJob do
  let(:redis_client) { instance_double(FraudOpsRedisClient) }
  let(:s3_client) { instance_double(Aws::S3::Client) }

  before do
    allow(IdentityConfig.store).to receive(:fraud_ops_tracker_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:s3_idp_dw_tasks).and_return('login-gov-idp-dw-tasks')
    allow(IdentityConfig.store).to receive(:aws_region).and_return('us-east-1')

    allow(FraudOpsRedisClient).to receive(:new).and_return(redis_client)
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)

    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when fraud ops tracker is enabled' do
      let(:test_events) do
        {
          'event-1' => 'encrypted-data-1',
          'event-2' => 'encrypted-data-2',
        }
      end

      before do
        allow(redis_client).to receive(:read_all_events).and_return(test_events)
        allow(redis_client).to receive(:delete_events).and_return(2)
        allow(redis_client).to receive(:clear_expired_keys).and_return(0)
        allow(s3_client).to receive(:put_object)
      end

      it 'reads events from Redis and uploads to S3' do
        subject.perform

        expect(redis_client).to have_received(:read_all_events).with(batch_size: 1000)
        expect(s3_client).to have_received(:put_object) do |args|
          expect(args[:bucket]).to eq('login-gov-idp-dw-tasks')
          expect(args[:key]).to match(/fraud-ops-events\/\d{4}\/\d{2}\/\d{2}\/events-\d+-[a-f0-9]+\.json/)
          expect(args[:content_type]).to eq('application/json')
          expect(args[:server_side_encryption]).to eq('AES256')

          body_data = JSON.parse(args[:body])
          expect(body_data['event_count']).to eq(2)
          expect(body_data['events']).to be_an(Array)
          expect(body_data['events'].first['jti']).to eq('event-1')
          expect(body_data['events'].first['encrypted_data']).to eq('encrypted-data-1')
        end
      end

      it 'deletes uploaded events from Redis' do
        subject.perform

        expect(redis_client).to have_received(:delete_events).with(keys: test_events.keys)
      end

      it 'cleans up expired Redis keys' do
        subject.perform

        expect(redis_client).to have_received(:clear_expired_keys)
      end

      it 'logs successful upload' do
        subject.perform

        expect(Rails.logger).to have_received(:info).with(/Successfully uploaded 2 events to s3/)
      end

      context 'when S3 upload fails' do
        before do
          allow(s3_client).to receive(:put_object).and_raise(
            Aws::S3::Errors::ServiceError.new(
              nil,
              'S3 Error',
            ),
          )
        end

        it 'logs the error and does not delete events from Redis' do
          subject.perform

          expect(Rails.logger).to have_received(:error).with(/Failed to upload events to S3/)
          expect(redis_client).not_to have_received(:delete_events)
        end
      end
    end

    context 'when fraud ops tracker is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:fraud_ops_tracker_enabled).and_return(false)
        allow(redis_client).to receive(:read_all_events)
        allow(s3_client).to receive(:put_object)
      end

      it 'does not process events' do
        subject.perform

        expect(redis_client).not_to have_received(:read_all_events)
        expect(s3_client).not_to have_received(:put_object)
      end
    end

    context 'when there are no events' do
      before do
        allow(redis_client).to receive(:read_all_events).and_return({})
        allow(redis_client).to receive(:clear_expired_keys).and_return(0)
        allow(s3_client).to receive(:put_object)
      end

      it 'does not upload to S3 but still cleans up' do
        subject.perform

        expect(s3_client).not_to have_received(:put_object)
        expect(redis_client).to have_received(:clear_expired_keys)
      end
    end

    context 'when S3 bucket is not configured' do
      before do
        allow(IdentityConfig.store).to receive(:s3_idp_dw_tasks).and_return('')
        allow(redis_client).to receive(:read_all_events).and_return({ 'event-1' => 'data-1' })
        allow(redis_client).to receive(:delete_events).and_return(0)
        allow(redis_client).to receive(:clear_expired_keys).and_return(0)
        allow(s3_client).to receive(:put_object)
      end

      it 'does not upload to S3' do
        subject.perform

        expect(s3_client).not_to have_received(:put_object)
      end
    end
  end
end
