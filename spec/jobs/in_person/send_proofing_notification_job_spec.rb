require 'rails_helper'

RSpec.describe InPerson::SendProofingNotificationJob do
  include Shoulda::Matchers::ActiveModel
  let(:job) { InPerson::SendProofingNotificationJob.new }
  let(:analytics) { FakeAnalytics.new }

  let(:passed_enrollment_without_notification) { create(:in_person_enrollment, :passed) }
  let(:passed_enrollment) do
    create(
      :in_person_enrollment,
      :passed,
      :with_notification_phone_configuration,
      proofed_at: Time.zone.now - 3.days,
      enrollment_code: '1234567890123456',
    )
  end
  let(:failing_enrollment) do
    create(
      :in_person_enrollment,
      :failed,
      :with_notification_phone_configuration,
      proofed_at: Time.zone.now - 3.days,
    )
  end
  let(:expired_enrollment) do
    create(:in_person_enrollment, :expired, :with_notification_phone_configuration)
  end
  let(:sms_success_response) do
    Telephony::Response.new(
      success: true,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
    )
  end
  let(:sms_opt_out_response) do
    Telephony::Response.new(
      success: false,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
      error: Telephony::OptOutError.new,
    )
  end
  let(:sms_failure_response) do
    Telephony::Response.new(
      success: false,
      extra: { request_id: 'fake-message-request-id', message_id: 'fake-message-id' },
      error: Telephony::DailyLimitReachedError.new,
    )
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(job).to receive(:analytics).and_return(analytics)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_send_proofing_notifications_enabled)
      .and_return(in_person_send_proofing_notifications_enabled)
  end

  describe '#perform' do
    context 'in person proofing disabled' do
      let(:in_person_proofing_enabled) { false }
      let(:in_person_send_proofing_notifications_enabled) { true }
      it 'returns without doing anything' do
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        job.perform(passed_enrollment.id)

        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job completed')
      end
    end

    context 'job disabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { false }
      it 'returns without doing anything' do
        expect(job).not_to receive(:poll)
        expect(job).not_to receive(:process_batch)
        job.perform(passed_enrollment.id)
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
        expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job completed')
      end
    end

    context 'ipp and job enabled' do
      let(:in_person_proofing_enabled) { true }
      let(:in_person_send_proofing_notifications_enabled) { true }

      context 'enrollment does not exist' do
        it 'returns without doing anything' do
          bad_id = (InPersonEnrollment.pluck(:id).max || 0) + 1
          job.perform(bad_id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end

      context 'enrollment has an unsupported status' do
        it 'returns without doing anything' do
          job.perform(expired_enrollment.id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end

      context 'without notification phone notification' do
        it 'returns without doing anything' do
          job.perform(passed_enrollment_without_notification.id)
          expect(analytics).not_to have_logged_event('SendProofingNotificationJob: job started')
          expect(analytics).to have_logged_event('SendProofingNotificationJob: job skipped')
        end
      end

      context 'with notification phone configuration' do
        it 'sends notification successfully when enrollment is successful and enrollment updated' do
          allow(Telephony).to receive(:send_notification).and_return(sms_success_response)

          freeze_time do
            now = Time.zone.now
            expect(passed_enrollment.reload.notification_sent_at).to be_nil

            job.perform(passed_enrollment.id)
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job started')
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job completed')
            expect(analytics).to have_logged_event(
              'SendProofingNotificationJob: in person notification SMS send attempted',
            )
            expect(passed_enrollment.reload.notification_sent_at).to eq(now)
            expect(passed_enrollment.reload.notification_phone_configuration).to be_nil
          end
        end

        it 'sends notification successfully when enrollment failed' do
          allow(Telephony).to receive(:send_notification).and_return(sms_success_response)

          freeze_time do
            now = Time.zone.now
            job.perform(failing_enrollment.id)
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job started')
            expect(analytics).to have_logged_event('SendProofingNotificationJob: job completed')
            expect(analytics).to have_logged_event(
              'SendProofingNotificationJob: in person notification SMS send attempted',
            )
            expect(failing_enrollment.reload.notification_sent_at).to eq(now)
            expect(failing_enrollment.reload.notification_phone_configuration).to be_nil
          end
        end

        context 'sends a message that respects the user email locale preference' do
          let(:proofed_date) { Time.zone.now }
          let(:phone_number) { passed_enrollment.notification_phone_configuration.formatted_phone }
          let(:contact_number) { '(844) 555-5555' }
          let(:reference_string) { passed_enrollment.enrollment_code }
          let(:formatted_string) { '1234-5678-9012-3456' }

          before do
            allow(Telephony).to receive(:send_notification).and_return(sms_success_response)
            allow(Idv::InPerson::EnrollmentCodeFormatter).to receive(:format)
              .and_return(formatted_string)
          end

          it 'handles English language preference' do
            passed_enrollment.user.update!(email_language: 'en')
            passed_enrollment.update!(proofed_at: Time.zone.now)
            formatted_date = I18n.l(proofed_date, format: :sms_date, locale: 'en')

            expect(Telephony)
              .to(
                receive(:send_notification)
                  .with(
                    to: phone_number,
                    message: "Login.gov: You visited the Post Office on #{formatted_date}." \
                      " Check email for your result." \
                      " Not you? Report this right away: #{contact_number}." \
                      " Ref: #{formatted_string}",
                    country_code: Phonelib.parse(phone_number).country,
                  ),
              )

            job.perform(passed_enrollment.id)
          end

          it 'handles French language preference' do
            passed_enrollment.user.update!(email_language: 'fr')
            passed_enrollment.update!(proofed_at: Time.zone.now)
            formatted_date = I18n.l(proofed_date, format: :sms_date, locale: 'fr')

            expect(Telephony)
              .to(
                receive(:send_notification)
                  .with(
                    to: phone_number,
                    message: "Login.gov : Vous avez visité le bureau de poste le " \
                    "#{formatted_date}. Vérifiez votre e-mail pour obtenir votre résultat. Ce" \
                    " n'est pas vous ? Signalez-le immédiatement : #{contact_number}. Réf. : " \
                    "#{formatted_string}",
                    country_code: Phonelib.parse(phone_number).country,
                  ),
              )

            job.perform(passed_enrollment.id)
          end

          it 'handles Spanish language preference' do
            passed_enrollment.user.update!(email_language: 'es')
            passed_enrollment.update!(proofed_at: Time.zone.now)
            formatted_date = I18n.l(proofed_date, format: :sms_date, locale: 'es')

            expect(Telephony)
              .to(
                receive(:send_notification)
                  .with(
                    to: phone_number,
                    message: "Login.gov: Usted acudió a la oficina de correos el " \
                      "#{formatted_date}. Revise el resultado en su correo electrónico. " \
                      "¿No fue usted? Informe inmediatamente de esto: #{contact_number}." \
                      " Ref: #{formatted_string}",
                    country_code: Phonelib.parse(phone_number).country,
                  ),
              )

            job.perform(passed_enrollment.id)
          end
        end
      end

      context 'when failed to send notification' do
        it 'logs sms send failure when number is opt out and enrollment not updated' do
          allow(Telephony).to receive(:send_notification).and_return(sms_opt_out_response)

          job.perform(passed_enrollment.id)
          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: in person notification SMS send attempted',
          )
          expect(passed_enrollment.reload.notification_sent_at).to be_nil
        end

        it 'logs sms send failure for delivery failure' do
          allow(Telephony).to receive(:send_notification).and_return(sms_failure_response)

          job.perform(passed_enrollment.id)
          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: in person notification SMS send attempted',
          )
          expect(passed_enrollment.reload.notification_sent_at).to be_nil
        end
      end

      context 'when an exception is raised trying to find the enrollment' do
        it 'logs the exception details' do
          allow(InPersonEnrollment)
            .to receive(:find_by)
            .and_raise(ActiveRecord::DatabaseConnectionError)

          job.perform(passed_enrollment.id)

          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: exception raised',
            enrollment_id: passed_enrollment.id,
            exception_class: 'ActiveRecord::DatabaseConnectionError',
            exception_message: 'Database connection error',
          )
        end
      end

      context 'when an exception is raised trying to send the notification' do
        let(:exception_message) { 'SMS unsupported' }

        it 'logs the exception details' do
          allow(Telephony)
            .to(
              receive(:send_notification)
              .and_raise(Telephony::SmsUnsupportedError.new(exception_message)),
            )

          job.perform(passed_enrollment.id)

          expect(analytics).to have_logged_event(
            'SendProofingNotificationJob: exception raised',
            enrollment_code: passed_enrollment.enrollment_code,
            enrollment_id: passed_enrollment.id,
            exception_class: 'Telephony::SmsUnsupportedError',
            exception_message: exception_message,
          )
        end
      end
    end
  end
end
