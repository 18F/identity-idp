require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentHelper do
  include UspsIppHelper
  include UspsIppServiceHelper

  let(:usps_mock_fallback) { false }
  let(:user) { build(:user) }
  let(:current_address_matches_id) { false }
  let(:applicant_pii) do
    Pii::UspsApplicant.from_idv_applicant(
      Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE
        .merge(same_address_as_id: current_address_matches_id ? true : false)
        .transform_keys(&:to_s),
    )
  end
  subject(:subject) { described_class }
  let(:subject_analytics) { FakeAnalytics.new }
  let(:service_provider) { nil }
  let(:usps_ipp_enrollment_status_update_email_address) do
    'registration@usps.local.identitysandbox.gov'
  end
  let(:is_enhanced_ipp) { false }
  let(:usps_ipp_sponsor_id) { '2718281828' }

  before(:each) do
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(usps_mock_fallback)
    allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address)
      .and_return(usps_ipp_enrollment_status_update_email_address)
    allow(subject).to receive(:analytics).and_return(subject_analytics)
    allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).and_return(usps_ipp_sponsor_id)
  end

  describe '.schedule_in_person_enrollment' do
    context 'when the user does not have an establishing InPersonEnrollment' do
      let(:user) { double('user', establishing_in_person_enrollment: nil) }

      it 'returns without error' do
        expect do
          subject.schedule_in_person_enrollment(user:, applicant_pii:, is_enhanced_ipp: false)
        end.not_to raise_error
      end
    end

    context 'when the user has an establishing InPersonEnrollment' do
      let!(:enrollment) do
        create(
          :in_person_enrollment,
          user: user,
          service_provider: service_provider,
          status: :establishing,
          current_address_matches_id: nil,
          profile: nil,
        )
      end
      let(:enrollment_code) { Faker::Number.number(digits: 10).to_s }
      let(:issuer) { 'this-is-an-issuer' }
      let(:service_provider) { build(:service_provider, issuer: issuer) }

      context 'when in-person mocking is enabled' do
        let(:usps_mock_fallback) { true }
        let(:mock_proofer) { instance_double(UspsInPersonProofing::Mock::Proofer) }
        let(:response) { double('UspsResponse') }

        before do
          allow(response).to receive(:enrollment_code).and_return(enrollment_code)
          allow(mock_proofer).to receive(:request_enroll).and_return(response)
          allow(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_return(mock_proofer)

          subject.schedule_in_person_enrollment(user:, applicant_pii:, is_enhanced_ipp:)
        end

        it 'uses a mock proofer' do
          expect(mock_proofer).to have_received(:request_enroll)
        end
      end

      context 'when in-person mocking is not enabled' do
        let(:usps_mock_fallback) { false }
        let(:opted_in) { true }
        let(:proofer) { instance_double(UspsInPersonProofing::Proofer) }

        before do
          allow(UspsInPersonProofing::Proofer).to receive(:new).and_return(proofer)
        end

        context 'when the USPS enrollment creation fails' do
          context 'when the USPS API error is Bad Request' do
            before do
              allow(proofer).to receive(:request_enroll).and_raise(
                Faraday::BadRequestError.new(
                  {
                    body: {
                      responseMessage: 'Failure',
                    },
                  },
                ),
              )
            end

            it 'raises a Exception::RequestEnrollException error' do
              expect do
                subject.schedule_in_person_enrollment(
                  user:, applicant_pii:, is_enhanced_ipp:, opt_in: opted_in,
                )
              end.to raise_error(UspsInPersonProofing::Exception::RequestEnrollException)
            end
          end

          context 'when the USPS API errors with ServerError' do
            before do
              allow(proofer).to receive(:request_enroll).and_raise(Faraday::ServerError)
            end

            it 'raises a Exception::RequestEnrollException error' do
              expect do
                subject.schedule_in_person_enrollment(
                  user:, applicant_pii:, is_enhanced_ipp:, opt_in: opted_in,
                )
              end.to raise_error(UspsInPersonProofing::Exception::RequestEnrollException)
            end
          end
        end

        context 'when the USPS enrollment creation is successful' do
          let(:current_time) { Time.zone.now }
          let(:response) { double('UspsResponse') }

          before do
            allow(response).to receive(:enrollment_code).and_return(enrollment_code)
            allow(proofer).to receive(:request_enroll).and_return(response)
            freeze_time
            travel_to(current_time) do
              subject.schedule_in_person_enrollment(
                user:, applicant_pii:, is_enhanced_ipp:, opt_in: opted_in,
              )
            end
          end

          it 'updates the enrollment' do
            expect(enrollment.reload).to have_attributes(
              enrollment_code: enrollment_code,
              current_address_matches_id: applicant_pii.current_address_same_as_id,
              status: 'pending',
              enrollment_established_at: current_time,
            )
          end

          it 'logs the usps_ippaas_enrollment_created event' do
            expect(subject_analytics).to have_logged_event(
              'USPS IPPaaS enrollment created',
              enrollment_code: enrollment_code,
              enrollment_id: enrollment.id,
              second_address_line_present: false,
              service_provider: issuer,
              opted_in_to_in_person_proofing: opted_in,
              enhanced_ipp: false,
            )
          end

          it 'sends a ready to verify email' do
            expect_delivered_email_count(1)
            expect_delivered_email(
              to: [user.email_addresses.first.email],
              subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
            )
          end
        end
      end
    end
  end

  describe '#cancel_establishing_and_in_progress_enrollments' do
    [:establishing, :pending, :in_fraud_review].each do |status|
      context "when the user has an '#{status}' in-person enrollment" do
        let!(:enrollment) { create(:in_person_enrollment, status, user: user) }

        before do
          subject.cancel_establishing_and_in_progress_enrollments(user)
        end

        it "cancels the user's in-person enrollment" do
          expect(enrollment.reload.status).to eq('cancelled')
        end
      end
    end

    context 'when the user has both establishing and pending in-person enrollments' do
      let!(:establishing_enrollment) { create(:in_person_enrollment, :establishing, user: user) }
      let!(:pending_enrollment) { create(:in_person_enrollment, :pending, user: user) }

      before do
        subject.cancel_establishing_and_in_progress_enrollments(user)
      end

      it "cancels the user's establishing in-person enrollment" do
        expect(establishing_enrollment.reload.status).to eq('cancelled')
      end

      it "cancels the user's pending in-person enrollment" do
        expect(pending_enrollment.reload.status).to eq('cancelled')
      end
    end

    context 'when the user has no establishing or in-progress in-person enrollments' do
      it 'does not throw an error' do
        expect { subject.cancel_establishing_and_in_progress_enrollments(user) }.not_to raise_error
      end
    end
  end
end
