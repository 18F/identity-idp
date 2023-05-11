require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline do
  subject(:enrollment_pipeline) { Class.new.include(described_class).new }

  describe '#process_message' do
    let(:sqs_message) { instance_double(Aws::SQS::Types::Message) }
    let(:sqs_message_id) { Random.uuid }
    let(:sns_message_id) { Random.uuid }
    let(:enrollment_code) { Random.uuid.delete('-').slice(0, 16) }
    let(:ses_payload) do
      {
        content: Mail.new do |m|
          m.body enrollment_code
        end.to_s,
        mail: {
          messageId: Random.uuid.delete('-'),
          timestamp: DateTime.now.to_s,
          source: 'testsource@example.com',
          commonHeaders: {
            date: Mail::DateField.new.to_s,
            messageId: Mail::Utilities.generate_message_id,
          },
        },
      }
    end
    let(:expected_error) { nil }
    let(:expected_error_extra) { nil }

    before(:each) do
      allow(enrollment_pipeline).to receive(:report_error)
      allow(sqs_message).to receive(:message_id).
        and_return(sqs_message_id)
    end

    def expect_error(error, **extra)
      expect(enrollment_pipeline).to receive(:report_error).
        with(error, **extra)
      expect(enrollment_pipeline.process_message(sqs_message)).to be(false)
    end

    context 'reports error and returns false' do
      it 'SQS message is not JSON' do
        allow(sqs_message).to receive(:body).and_return('not json')
        expect_error(StandardError.new, { sqs_message_id: })
      end

      it 'SQS message body is not a hash' do
        allow(sqs_message).to receive(:body).and_return('abcd'.to_json)
        expect_error(StandardError.new, { sqs_message_id: })
      end

      it 'SNS message is missing MessageId' do
        allow(sqs_message).to receive(:body).and_return(
          {
            Message: 'abcd',
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id: })
      end

      it 'SNS message is missing Message' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id: })
      end

      it 'SNS "Message" field is not JSON' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: 'not json',
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'SES message is not a hash' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: 'abcd'.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'SES message is missing "content" key' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              mail: {},
            }.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'SES message is missing "mail" key' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              content: 'abcd',
            }.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'SES message is missing "mail" key' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              content: 'abcd',
            }.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'email body is missing' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              content: {
                **ses_payload,
                content: nil,
              },
            }.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end

      it 'email body does not match pattern' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              content: {
                **ses_payload,
                content: Mail.new do |m|
                  m.body 'abcd'
                end.to_s,
              },
            }.to_json,
          }.to_json,
        )
        expect_error(StandardError.new, { sqs_message_id:, sns_message_id: })
      end
    end
  end
end
