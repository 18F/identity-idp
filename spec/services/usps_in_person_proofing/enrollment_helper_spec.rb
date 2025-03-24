require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentHelper do
  include UspsIppHelper
  include UspsIppServiceHelper

  let(:usps_mock_fallback) { false }
  let(:user) { build(:user) }
  let(:current_address_matches_id) { false }
  let(:pii) do
    Pii::Attributes.new_from_hash(
      Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE
        .merge(same_address_as_id: current_address_matches_id ? 'true' : 'false')
        .transform_keys(&:to_s),
    )
  end
  subject(:subject) { described_class }
  let(:subject_analytics) { FakeAnalytics.new }
  let(:transliterator) { UspsInPersonProofing::Transliterator.new }
  let(:service_provider) { nil }
  let(:usps_ipp_enrollment_status_update_email_address) do
    'registration@usps.local.identitysandbox.gov'
  end
  let(:proofer) { UspsInPersonProofing::Mock::Proofer.new }
  let(:is_enhanced_ipp) { false }
  let(:usps_ipp_sponsor_id) { '2718281828' }
  let(:current_sp) { create(:service_provider) }
  let(:view_context) { ActionController::Base.new.view_context }
  let(:sp) { build_stubbed(:service_provider, logo: nil) }
  let(:decorated_sp_session) do
    ServiceProviderSessionCreator.new(
      sp: sp,
      view_context: view_context,
      sp_session: { issuer: current_sp.issuer },
      service_provider_request: ServiceProviderRequestProxy.new,
    ).create_session
  end

  before(:each) do
    stub_request_token
    stub_request_enroll
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(usps_mock_fallback)
    allow(IdentityConfig.store).to receive(:usps_ipp_enrollment_status_update_email_address)
      .and_return(usps_ipp_enrollment_status_update_email_address)
    allow(subject).to receive(:transliterator).and_return(transliterator)
    allow(transliterator).to receive(:transliterate)
      .with(anything) do |val|
        transliterated_without_change(val)
      end
    allow(subject).to receive(:analytics).and_return(subject_analytics)
    allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).and_return(usps_ipp_sponsor_id)
  end

  describe '#schedule_in_person_enrollment' do
    context 'when the user does not have an establishing in person enrollment' do
      let(:user) { double('user', establishing_in_person_enrollment: nil) }

      it 'returns without error' do
        expect do
          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp: false,
            decorated_sp_session:
          )
        end.not_to raise_error
      end
    end

    context 'when the user has an establishing in person enrollment' do
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

      context 'when in-person mocking is enabled' do
        let(:usps_mock_fallback) { true }

        it 'uses a mock proofer' do
          expect(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_call_original

          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp:,
            decorated_sp_session:
          )
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

          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp:,
            decorated_sp_session:
          )
          enrollment.reload

          # tests that the value of current_address_matches_id on the enrollment corresponds
          # to the value of same_address_as_id in the session
          expect(enrollment.current_address_matches_id).to eq(current_address_matches_id)
        end

        it 'creates usps enrollment while using transliteration' do
          first_name = Idp::Constants::MOCK_IDV_APPLICANT[:first_name]
          last_name = Idp::Constants::MOCK_IDV_APPLICANT[:last_name]
          address = Idp::Constants::MOCK_IDV_APPLICANT[:address1]
          city = Idp::Constants::MOCK_IDV_APPLICANT[:city]

          expect(transliterator).to receive(:transliterate)
            .with(first_name).and_return(transliterated_without_change(first_name))
          expect(transliterator).to receive(:transliterate)
            .with(last_name).and_return(transliterated(last_name))
          expect(transliterator).to receive(:transliterate)
            .with(address).and_return(transliterated_with_failure(address))
          expect(transliterator).to receive(:transliterate)
            .with(city).and_return(transliterated(city))

          expect(proofer).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq(first_name)
            expect(applicant.last_name).to eq("transliterated_#{last_name}")
            expect(applicant.address).to eq(address)
            expect(applicant.city).to eq("transliterated_#{city}")
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.email).to eq(usps_ipp_enrollment_status_update_email_address)
            expect(applicant.unique_id).to eq(enrollment.unique_id)

            UspsInPersonProofing::Mock::Proofer.new.request_enroll(applicant, is_enhanced_ipp)
          end

          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp:,
            decorated_sp_session:
          )
        end

        it <<~STR.squish do
          sets enrollment status to pending, sponsor_id to usps_ipp_sponsor_id,
          and sets established at date and unique id
        STR
          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp:,
            decorated_sp_session:
          )

          expect(user.in_person_enrollments.first.status).to eq(InPersonEnrollment::STATUS_PENDING)
          expect(user.in_person_enrollments.first.sponsor_id).to eq(usps_ipp_sponsor_id)
          expect(user.in_person_enrollments.first.enrollment_established_at).to_not be_nil
          expect(user.in_person_enrollments.first.unique_id).to_not be_nil
        end

        context 'event logging' do
          context 'with no service provider' do
            it 'logs event' do
              subject.schedule_in_person_enrollment(
                user:, pii:, is_enhanced_ipp:,
                decorated_sp_session:
              )

              expect(subject_analytics).to have_logged_event(
                'USPS IPPaaS enrollment created',
                enrollment_code: user.in_person_enrollments.first.enrollment_code,
                enrollment_id: user.in_person_enrollments.first.id,
                second_address_line_present: false,
                enhanced_ipp: false,
              )
            end
          end

          context 'with a service provider' do
            let(:issuer) { 'this-is-an-issuer' }
            let(:service_provider) { build(:service_provider, issuer: issuer) }

            context 'when the enrollment is enhanced_ipp' do
              let!(:enrollment) do
                create(
                  :in_person_enrollment,
                  :enhanced_ipp,
                  user: user,
                  service_provider: service_provider,
                  status: :establishing,
                  current_address_matches_id: nil,
                  profile: nil,
                )
              end
              let(:is_enhanced_ipp) { true }

              it 'logs event' do
                subject.schedule_in_person_enrollment(
                  user:, pii:, is_enhanced_ipp:,
                  decorated_sp_session:
                )

                expect(subject_analytics).to have_logged_event(
                  'USPS IPPaaS enrollment created',
                  enrollment_code: user.in_person_enrollments.first.enrollment_code,
                  enrollment_id: user.in_person_enrollments.first.id,
                  second_address_line_present: false,
                  service_provider: issuer,
                  enhanced_ipp: true,
                )
              end
            end

            context 'when the enrollment is not enhanced_ipp' do
              it 'logs event' do
                subject.schedule_in_person_enrollment(
                  user:, pii:, is_enhanced_ipp:,
                  decorated_sp_session:
                )

                expect(subject_analytics).to have_logged_event(
                  'USPS IPPaaS enrollment created',
                  enrollment_code: user.in_person_enrollments.first.enrollment_code,
                  enrollment_id: user.in_person_enrollments.first.id,
                  second_address_line_present: false,
                  service_provider: issuer,
                  enhanced_ipp: false,
                )
              end
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

              subject.schedule_in_person_enrollment(
                user:, pii:, is_enhanced_ipp:,
                decorated_sp_session:
              )

              expect(subject_analytics).to have_logged_event(
                'USPS IPPaaS enrollment created',
                enrollment_code: user.in_person_enrollments.first.enrollment_code,
                enrollment_id: user.in_person_enrollments.first.id,
                second_address_line_present: false,
                enhanced_ipp: false,
              )
            end

            context 'with address line 2 present in state ID address' do
              it 'logs the presence of address line 2' do
                expect(pii['identity_doc_address2'].present?).to eq(true)

                pii['same_address_as_id'] = false
                pii['address2'] = nil

                subject.schedule_in_person_enrollment(
                  user:, pii:, is_enhanced_ipp:,
                  decorated_sp_session:
                )

                expect(subject_analytics).to have_logged_event(
                  'USPS IPPaaS enrollment created',
                  enrollment_code: user.in_person_enrollments.first.enrollment_code,
                  enrollment_id: user.in_person_enrollments.first.id,
                  second_address_line_present: true,
                  enhanced_ipp: false,
                )
              end
            end
          end

          context 'with opt in value' do
            let(:opt_in) { true }

            it 'logs user\'s opt-in choice' do
              subject.schedule_in_person_enrollment(
                user:, pii:, is_enhanced_ipp:,
                decorated_sp_session:, opt_in:
              )

              expect(subject_analytics).to have_logged_event(
                'USPS IPPaaS enrollment created',
                enrollment_code: user.in_person_enrollments.first.enrollment_code,
                enrollment_id: user.in_person_enrollments.first.id,
                opted_in_to_in_person_proofing: true,
                second_address_line_present: false,
                enhanced_ipp: false,
              )
            end
          end
        end

        it 'sends verification emails' do
          subject.schedule_in_person_enrollment(
            user:, pii:, is_enhanced_ipp:,
            decorated_sp_session:
          )

          expect_delivered_email_count(1)
          expect_delivered_email(
            to: [user.email_addresses.first.email],
            subject: t('user_mailer.in_person_ready_to_verify.subject', app_name: APP_NAME),
          )
        end
      end
    end
  end

  describe '#create_usps_enrollment' do
    let(:usps_mock_fallback) { true }
    let(:usps_eipp_sponsor_id) { '314159265359' }
    let(:pii) do
      Pii::Attributes.new_from_hash(
        Idp::Constants::MOCK_IDV_APPLICANT,
      )
    end
    let(:applicant) do
      UspsInPersonProofing::Applicant.new(
        unique_id: enrollment.unique_id,
        first_name: Idp::Constants::MOCK_IDV_APPLICANT[:first_name],
        last_name: Idp::Constants::MOCK_IDV_APPLICANT[:last_name],
        address: Idp::Constants::MOCK_IDV_APPLICANT[:address1],
        city: Idp::Constants::MOCK_IDV_APPLICANT[:city],
        state: Idp::Constants::MOCK_IDV_APPLICANT[:state],
        zip_code: Idp::Constants::MOCK_IDV_APPLICANT[:zipcode],
        email: usps_ipp_enrollment_status_update_email_address,
      )
    end
    before do
      allow(IdentityConfig.store).to receive(:usps_eipp_sponsor_id)
        .and_return(usps_eipp_sponsor_id)
      allow(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_return(proofer)
      allow(proofer).to receive(:request_enroll).and_call_original
    end
    context 'when the user is going through enhanced ipp' do
      let!(:enrollment) do
        create(
          :in_person_enrollment,
          :enhanced_ipp,
          user: user,
          service_provider: service_provider,
          status: :establishing,
          profile: nil,
        )
      end
      let(:is_enhanced_ipp) { true }

      it 'creates an enhanced ipp enrollment' do
        expect(proofer).to receive(:request_enroll).with(applicant, is_enhanced_ipp)
        subject.create_usps_enrollment(enrollment, pii, is_enhanced_ipp)
      end

      it 'saves sponsor_id on the enrollment to the usps_eipp_sponsor_id' do
        subject.schedule_in_person_enrollment(user:, pii:, is_enhanced_ipp:, decorated_sp_session:)

        expect(user.in_person_enrollments.first.sponsor_id).to eq(usps_eipp_sponsor_id)
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
