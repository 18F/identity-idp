require 'rails_helper'

RSpec.describe InPerson::EnrollmentsReadyForStatusCheck::EnrollmentPipeline do
  let(:error_reporter) { instance_double(InPerson::EnrollmentsReadyForStatusCheck::ErrorReporter) }
  let(:email_body_pattern) { /\A\s*(?<enrollment_code>\d{16})\s*\Z/ }
  subject(:enrollment_pipeline) { described_class.new(error_reporter:, email_body_pattern:) }

  let(:pipeline_analytics) { FakeAnalytics.new }

  before(:each) do
    allow(IdentityConfig.store).to receive(:in_person_enrollments_ready_job_email_body_pattern).
      and_return('\A\s*(?<enrollment_code>\d{16})\s*\Z')

    allow(error_reporter).to receive(:report_error)
  end

  describe '#process_message' do
    let(:sqs_message) { instance_double(Aws::SQS::Types::Message) }
    let(:sqs_message_id) { Random.uuid }
    let(:sns_message_id) { Random.uuid }
    let(:enrollment_code) { 16.times.map { rand(0..9) }.join }
    let(:user) { create(:user) }
    let(:user_id) { user.id }
    let(:mail_date) { 16.hours.ago.to_datetime }
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
            date: Mail::DateField.new(mail_date).to_s,
            messageId: Mail::Utilities.generate_message_id,
          },
        },
      }
    end
    let(:ses_text_payload) do
      {
        content: Mail.new do |m|
          m.text_part = enrollment_code
        end.to_s,
        mail: {
          messageId: Random.uuid.delete('-'),
          timestamp: DateTime.now.to_s,
          source: 'testsource@example.com',
          commonHeaders: {
            date: Mail::DateField.new(mail_date).to_s,
            messageId: Mail::Utilities.generate_message_id,
          },
        },
      }
    end
    let(:ses_html_payload) do
      {
        content: Mail.new do |m|
          m.html_part = enrollment_code
        end.to_s,
        mail: {
          messageId: Random.uuid.delete('-'),
          timestamp: DateTime.now.to_s,
          source: 'testsource@example.com',
          commonHeaders: {
            date: Mail::DateField.new(mail_date).to_s,
            messageId: Mail::Utilities.generate_message_id,
          },
        },
      }
    end
    let(:ses_body_payload) do
      {
        content: Mail.new do |m|
          m.body = enrollment_code
        end.to_s,
        mail: {
          messageId: Random.uuid.delete('-'),
          timestamp: DateTime.now.to_s,
          source: 'testsource@example.com',
          commonHeaders: {
            date: Mail::DateField.new(mail_date).to_s,
            messageId: Mail::Utilities.generate_message_id,
          },
        },
      }
    end
    let(:logged_ses_values) do
      {
        ses_aws_message_id: ses_payload[:mail][:messageId],
        ses_mail_source: ses_payload[:mail][:source],
        ses_mail_timestamp: ses_payload[:mail][:timestamp],
        ses_rfc_message_id: ses_payload[:mail][:commonHeaders][:messageId],
        ses_rfc_origination_date: mail_date.to_s,
      }
    end
    let(:sns_payload) do
      {
        MessageId: sns_message_id,
        Message: ses_payload.to_json,
      }
    end
    let(:sns_text_payload) do
      {
        MessageId: sns_message_id,
        Message: ses_text_payload.to_json,
      }
    end
    let(:sns_html_payload) do
      {
        MessageId: sns_message_id,
        Message: ses_html_payload.to_json,
      }
    end
    let(:sns_body_payload) do
      {
        MessageId: sns_message_id,
        Message: ses_body_payload.to_json,
      }
    end
    let(:expected_error) { nil }
    let(:expected_error_extra) { nil }

    before(:each) do
      allow(sqs_message).to receive(:message_id).
        and_return(sqs_message_id)
    end

    def expect_error(error, **extra)
      expect(error_reporter).to receive(:report_error) do |err, err_extra|
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
          'SNS "Message" field is not a valid SES payload',
          sqs_message_id:,
          sns_message_id:,
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

      it 'email body is missing (single part)' do
        message = Mail.new
        expect(message.multipart?).to be(false)
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              **ses_payload,
              content: message.to_s,
            }.to_json,
          }.to_json,
        )
        expect_error(
          'Failure occurred when attempting to get email body',
          sqs_message_id:,
          sns_message_id:,
          **logged_ses_values,
        )
      end

      it 'email body is missing (multipart)' do
        message = Mail.new do
          html_part do
            body nil
          end
          text_part do
            body nil
          end
        end
        expect(message.multipart?).to be(true)
        allow(sqs_message).to receive(:body).and_return(
          {
            MessageId: sns_message_id,
            Message: {
              **ses_payload,
              content: message.to_s,
            }.to_json,
          }.to_json,
        )
        expect_error(
          'Failure occurred when attempting to get email body',
          sqs_message_id:,
          sns_message_id:,
          **logged_ses_values,
        )
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
          sqs_message_id:,
          sns_message_id:,
          **logged_ses_values,
        )
      end

      it 'enrollment does not exist' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)
        expect_error(
          'Received code for enrollment that does not exist in the database',
          sqs_message_id:,
          sns_message_id:,
          enrollment_code:,
          **logged_ses_values,
        )
      end
    end

    context 'reports and rethrows unhandled errors' do
      it 'error thrown trying to fetch enrollment' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)
        error = ActiveRecord::ConnectionNotEstablished.new
        expect(InPersonEnrollment).to receive_message_chain(
          :where,
          :order,
          :limit,
          :pick,
        ).and_raise(error)

        expect(error_reporter).to receive(:report_error).
          with(
            error,
            sqs_message_id:,
            sns_message_id:,
            enrollment_code:,
            **logged_ses_values,
          )

        expect do
          enrollment_pipeline.process_message(sqs_message)
        end.to raise_error(error)
      end

      it 'error thrown trying to update enrollment' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending, user:)

        error = ActiveRecord::ConnectionNotEstablished.new
        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).
          and_raise(error)

        expect(error_reporter).to receive(:report_error).
          with(
            error,
            sqs_message_id:,
            sns_message_id:,
            enrollment_code:,
            user_id:,
            enrollment_id: enrollment.id,
            **logged_ses_values,
          )

        expect do
          enrollment_pipeline.process_message(sqs_message)
        end.to raise_error(error)
      end
    end

    context 'returns true for records handled as expected' do
      before do
        allow(enrollment_pipeline).to receive(:analytics).and_return(pipeline_analytics)
      end

      it 'handles text_part' do
        allow(sqs_message).to receive(:body).and_return(sns_text_payload.to_json)
        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending, user:)

        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).once

        expect(error_reporter).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).to be(true)

        expect(pipeline_analytics).to have_logged_event(
          'IdV: in person usps proofing enrollment code email received',
          multi_part: true,
          part_found: 'text_part',
        )
      end

      it 'handles html_part' do
        allow(sqs_message).to receive(:body).and_return(sns_html_payload.to_json)
        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending, user:)

        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).once

        expect(error_reporter).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).to be(true)

        expect(pipeline_analytics).to have_logged_event(
          'IdV: in person usps proofing enrollment code email received',
          multi_part: true,
          part_found: 'html_part',
        )
      end

      it 'handles message body' do
        allow(sqs_message).to receive(:body).and_return(sns_body_payload.to_json)

        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending, user:)

        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).once

        expect(error_reporter).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).to be(true)

        expect(pipeline_analytics).to have_logged_event(
          'IdV: in person usps proofing enrollment code email received',
          multi_part: false,
          part_found: 'message_body',
        )
      end
      it 'marks non-ready record as ready' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        enrollment = create(:in_person_enrollment, enrollment_code:, status: :pending, user:)

        expect(InPersonEnrollment).to receive(:update).
          with(enrollment.id, ready_for_status_check: true).once

        expect(error_reporter).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).to be(true)
      end
      it 'leaves record already marked as ready' do
        allow(sqs_message).to receive(:body).and_return(sns_payload.to_json)

        create(
          :in_person_enrollment, enrollment_code:, status: :pending, user:,
                                 ready_for_status_check: true
        )

        expect(InPersonEnrollment).not_to receive(:update)

        expect(error_reporter).not_to receive(:report_error)

        expect(enrollment_pipeline.process_message(sqs_message)).to be(true)
      end
    end
  end
end
