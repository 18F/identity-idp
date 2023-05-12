require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline do
  subject(:enrollment_pipeline) { Class.new.include(described_class).new }

  before(:each) do
    allow(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_email_body_pattern).
      and_return('/\A\s*(?<enrollment_code>\d{16})\s*\Z/')
  end

  describe '#process_message' do
    let(:sqs_message) { instance_double(Aws::SQS::Types::Message) }
    let(:sqs_message_id) { Random.uuid }
    let(:sns_message_id) { Random.uuid }
    let(:enrollment_code) { Random.uuid.delete('-').slice(0, 16) }
    let(:ses_payload) do
      {
        content: Mail.new do |m|
          m.text_part = enrollment_code
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
    let(:sns_payload) do
      {
        MessageId: sns_message_id,
        Message: ses_payload.to_json,
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
      expect(enrollment_pipeline).to receive(:report_error) do |err, err_extra|
        expect(err).to eq(error) if error.is_a?(String)
        expect(err.message).to eq(error.message) if error.is_a?(StandardError)
        expect(err.class).to eq(error.class)
        expect(err_extra).to eq(extra)
      end
      expect(enrollment_pipeline.process_message(sqs_message)).to be(false)
    end

    context 'reports error and returns false' do
      it 'SQS message is not JSON' do
        allow(sqs_message).to receive(:body).and_return('not json')
        expect_error(JSON::ParserError.new("unexpected token at 'not json'"), sqs_message_id:)
      end

      it 'SQS message body is not a hash' do
        allow(sqs_message).to receive(:body).and_return('abcd'.to_json)
        expect_error('SQS message body is not valid SNS payload', sqs_message_id:)
      end

      it 'SNS message is missing MessageId' do
        allow(sqs_message).to receive(:body).and_return(
          {
            Message: 'abcd',
          }.to_json,
        )
        expect_error('SQS message body is not valid SNS payload', sqs_message_id:)
      end

      it 'SNS message is missing Message' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
          }.to_json,
        )
        expect_error('SQS message body is not valid SNS payload', sqs_message_id:)
      end

      it 'SNS "Message" field is not JSON' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: 'not json',
          }.to_json,
        )
        expect_error(
          JSON::ParserError.new("unexpected token at 'not json'"), sqs_message_id:,
                                                                   sns_message_id:
        )
      end

      it 'SES message is not a hash' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: 'abcd'.to_json,
          }.to_json,
        )
        expect_error(
          'SNS "Message" field is not a valid SES payload', sqs_message_id:,
                                                            sns_message_id:
        )
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
        expect_error(
          'SNS "Message" field is not a valid SES payload', sqs_message_id:,
                                                            sns_message_id:
        )
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
        expect_error(
          'SNS "Message" field is not a valid SES payload', sqs_message_id:,
                                                            sns_message_id:
        )
      end

      it 'email content key is missing' do
        payload = ses_payload
        payload.delete(:content)
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              **payload,
            }.to_json,
          }.to_json,
        )
        expect_error(
          'SNS "Message" field is not a valid SES payload', sqs_message_id:,
                                                            sns_message_id:
        )
      end

      it 'email body is missing' do
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              **ses_payload,
              content: Mail.new,
            }.to_json,
          }.to_json,
        )
        expect_error('Email body is not a string', sqs_message_id:, sns_message_id:)
      end

      it 'email body does not match pattern' do
        allow(sqs_message).to receive(:body).and_return(
          {
            **sns_payload,
            Message: {
              **ses_payload,
              content: Mail.new do |m|
                m.text_part = 'abcd'
              end.to_s,
            }.to_json,
          }.to_json,
        )
        expect_error(
          'Failed to extract enrollment code using regex, check email body format and regex',
          sqs_message_id:, sns_message_id:,
          **{
            enrollment_code: nil,
            ses_aws_message_id: ses_payload[:mail][:messageId],
            ses_mail_source: ses_payload[:source],
            ses_mail_timestamp: ses_payload[:timestamp],
            ses_rfc_message_id: ses_payload[:commonHeaders][:messageId],
            ses_rfc_origination_date: ses_payload[:commonHeaders][:date],
          }
        )
      end

      it 'enrollment does not exist' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)
        expect_error(StandardError.new, sqs_message_id:, sns_message_id:, enrollment_code:)
      end
    end

    context 'reports and rethrows unhandled errors' do
      it 'error thrown trying to fetch enrollment' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)
        error = ActiveRecord::ConnectionNotEstablished.new
        expect(InPersonEnrollment).to receive(:pick).and_raise(error)

        expect(enrollment_pipeline).to receive(:report_error).
          with(error, { sqs_message_id:, sns_message_id:, enrollment_code: })

        expect do
          enrollment_pipeline.process_message(sqs_message)
        end.to raise_error(error)
      end

      it 'error thrown trying to update enrollment' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending)

        error = ActiveRecord::ConnectionNotEstablished.new
        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).
          and_raise(error)

        expect(enrollment_pipeline).to receive(:report_error).
          with(
            error,
            { sqs_message_id:, sns_message_id:, enrollment_code:, enrollment_id: enrollment.id },
          )

        expect do
          enrollment_pipeline.process_message(sqs_message)
        end.to raise_error(error)
      end
    end

    context 'returns true for records handled as expected' do
      it 'marks non-ready record as ready' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending)

        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).once

        expect(enrollment_pipeline).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).be(true)
      end
      it 'leaves record already marked as ready' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        create(
          :in_person_enrollment, enrollment_code:, status: :pending,
                                 ready_for_status_check: true
        )

        expect(InPersonEnrollment).not_to receive(:update)

        expect(enrollment_pipeline).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).be(true)
      end
    end
  end
end
