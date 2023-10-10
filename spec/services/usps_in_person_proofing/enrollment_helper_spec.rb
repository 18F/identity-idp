require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentHelper do
  include UspsIppHelper

  let(:usps_mock_fallback) { false }
  let(:user) { build(:user) }
  let(:current_address_matches_id) { false }
  let(:pii) do
    Pii::Attributes.new_from_hash(
      Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE.
        merge(same_address_as_id: current_address_matches_id ? 'true' : 'false').
        transform_keys(&:to_s),
    )
  end
  subject(:subject) { described_class }
  let(:subject_analytics) { FakeAnalytics.new }
  let(:transliterator) { UspsInPersonProofing::Transliterator.new }
  let(:service_provider) { nil }
  let(:usps_ipp_transliteration_enabled) { true }
  let(:usps_ipp_enrollment_status_update_email_address) do
    'registration@usps.local.identitysandbox.gov'
  end
  let(:proofer) { UspsInPersonProofing::Mock::Proofer.new }

  before(:each) do
    stub_request_token
    stub_request_enroll
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(usps_mock_fallback)
    allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address).
      and_return(usps_ipp_enrollment_status_update_email_address)
    allow(subject).to receive(:transliterator).and_return(transliterator)
    allow(transliterator).to receive(:transliterate).
      with(anything) do |val|
        transliterated_without_change(val)
      end
    allow(subject).to receive(:analytics).and_return(subject_analytics)
    allow(IdentityConfig.store).to receive(:usps_ipp_transliteration_enabled).
      and_return(usps_ipp_transliteration_enabled)
  end

  describe '#schedule_in_person_enrollment' do
    let!(:enrollment) do
      create(
        :in_person_enrollment,
        user: user,
        service_provider: service_provider,
        status: :establishing,
        profile: nil,
      )
    end

    context 'when in-person mocking is enabled' do
      let(:usps_mock_fallback) { true }

      it 'uses a mock proofer' do
        expect(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_call_original

        subject.schedule_in_person_enrollment(user, pii)
      end
    end

    context 'an establishing enrollment record exists for the user' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        allow(subject).to receive(:usps_proofer).and_return(proofer)
      end

      it 'updates the existing enrollment record' do
        expect(user.in_person_enrollments.length).to eq(1)

        subject.schedule_in_person_enrollment(user, pii)
        enrollment.reload

        # tests that the value of current_address_matches_id on the enrollment corresponds
        # to the value of same_address_as_id in the session
        expect(enrollment.current_address_matches_id).to eq(current_address_matches_id)
      end

      context 'transliteration disabled' do
        let(:usps_ipp_transliteration_enabled) { false }

        it 'creates usps enrollment without using transliteration' do
          expect(transliterator).not_to receive(:transliterate)
          expect(proofer).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
            expect(applicant.last_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
            expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
            expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.unique_id).to eq(enrollment.unique_id)

            UspsInPersonProofing::Mock::Proofer.new.request_enroll(applicant)
          end

          subject.schedule_in_person_enrollment(user, pii)
        end

        context 'same address as id is false' do
          let(:pii) do
            Pii::Attributes.new_from_hash(
              Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.
                merge(same_address_as_id: current_address_matches_id ? 'true' : 'false').
                merge(Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS).
                transform_keys(&:to_s),
            )
          end

          it 'maps enrollment address fields' do
            expect(proofer).to receive(:request_enroll) do |applicant|
              ADDR = Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS
              expect(applicant).to have_attributes(
                address: Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[
                  :identity_doc_address1
                ],
                city: Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_city],
                state: Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[
                  :identity_doc_address_state
                ],
                zip_code:
                  Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS[:identity_doc_zipcode],
              )
              UspsInPersonProofing::Mock::Proofer.new.request_enroll(applicant)
            end

            subject.schedule_in_person_enrollment(user, pii)
          end
        end
      end

      context 'transliteration enabled' do
        let(:usps_ipp_transliteration_enabled) { true }

        it 'creates usps enrollment while using transliteration' do
          first_name = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
          last_name = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
          address = Idp::Constants::MOCK_IDV_APPLICANT[:address1]
          city = Idp::Constants::MOCK_IDV_APPLICANT[:city]

          expect(transliterator).to receive(:transliterate).
            with(first_name).and_return(transliterated_without_change(first_name))
          expect(transliterator).to receive(:transliterate).
            with(last_name).and_return(transliterated(last_name))
          expect(transliterator).to receive(:transliterate).
            with(address).and_return(transliterated_with_failure(address))
          expect(transliterator).to receive(:transliterate).
            with(city).and_return(transliterated(city))

          expect(proofer).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq(first_name)
            expect(applicant.last_name).to eq("transliterated_#{last_name}")
            expect(applicant.address).to eq(address)
            expect(applicant.city).to eq("transliterated_#{city}")
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.email).to eq(usps_ipp_enrollment_status_update_email_address)
            expect(applicant.unique_id).to eq(enrollment.unique_id)

            UspsInPersonProofing::Mock::Proofer.new.request_enroll(applicant)
          end

          subject.schedule_in_person_enrollment(user, pii)
        end
      end

      context 'when the enrollment does not have a unique ID' do
        it 'uses the deprecated InPersonEnrollment#usps_unique_id value to create the enrollment' do
          enrollment.update(unique_id: nil)
          expect(proofer).to receive(:request_enroll) do |applicant|
            expect(applicant.unique_id).to eq(enrollment.usps_unique_id)

            UspsInPersonProofing::Mock::Proofer.new.request_enroll(applicant)
          end

          subject.schedule_in_person_enrollment(user, pii)
        end
      end

      it 'sets enrollment status to pending and sets established at date and unique id' do
        subject.schedule_in_person_enrollment(user, pii)

        expect(user.in_person_enrollments.first.status).to eq(InPersonEnrollment::STATUS_PENDING)
        expect(user.in_person_enrollments.first.enrollment_established_at).to_not be_nil
        expect(user.in_person_enrollments.first.unique_id).to_not be_nil
      end

      context 'event logging' do
        context 'with no service provider' do
          it 'logs event' do
            subject.schedule_in_person_enrollment(user, pii)

            expect(subject_analytics).to have_logged_event(
              'USPS IPPaaS enrollment created',
              enrollment_code: user.in_person_enrollments.first.enrollment_code,
              enrollment_id: user.in_person_enrollments.first.id,
              second_address_line_present: false,
              service_provider: nil,
            )
          end
        end

        context 'with a service provider' do
          let(:issuer) { 'this-is-an-issuer' }
          let(:service_provider) { build(:service_provider, issuer: issuer) }

          it 'logs event' do
            subject.schedule_in_person_enrollment(user, pii)

            expect(subject_analytics).to have_logged_event(
              'USPS IPPaaS enrollment created',
              enrollment_code: user.in_person_enrollments.first.enrollment_code,
              enrollment_id: user.in_person_enrollments.first.id,
              second_address_line_present: false,
              service_provider: issuer,
            )
          end
        end

        context 'with address line 2 present' do
          before { pii['address2'] = 'Apartment 227' }

          # this is a pii bundle that adds identity_doc_* values
          let(:pii) do
            Pii::Attributes.new_from_hash(
              Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS.transform_keys(&:to_s),
            )
          end

          it 'does not log the presence of address line 2 only in residential address' do
            pii['identity_doc_address2'] = nil

            subject.schedule_in_person_enrollment(user, pii)

            expect(subject_analytics).to have_logged_event(
              'USPS IPPaaS enrollment created',
              enrollment_code: user.in_person_enrollments.first.enrollment_code,
              enrollment_id: user.in_person_enrollments.first.id,
              second_address_line_present: false,
              service_provider: nil,
            )
          end

          context 'with address line 2 present in state ID address' do
            it 'logs the presence of address line 2' do
              expect(pii['identity_doc_address2'].present?).to eq(true)

              pii['same_address_as_id'] = false
              pii['address2'] = nil

              subject.schedule_in_person_enrollment(user, pii)

              expect(subject_analytics).to have_logged_event(
                'USPS IPPaaS enrollment created',
                enrollment_code: user.in_person_enrollments.first.enrollment_code,
                enrollment_id: user.in_person_enrollments.first.id,
                second_address_line_present: true,
                service_provider: nil,
              )
            end
          end
        end
      end

      it 'sends verification emails' do
        subject.schedule_in_person_enrollment(user, pii)

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [user.email_addresses.first.email],
          subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
        )
      end
    end
  end

  def transliterated_without_change(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: false,
      original: value,
      transliterated: value,
      unsupported_chars: [],
    )
  end

  def transliterated(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: true,
      original: value,
      transliterated: "transliterated_#{value}",
      unsupported_chars: [],
    )
  end

  def transliterated_with_failure(value)
    UspsInPersonProofing::Transliterator::TransliterationResult.new(
      changed?: true,
      original: value,
      transliterated: "transliterated_failed_#{value}",
      unsupported_chars: [':'],
    )
  end
end
