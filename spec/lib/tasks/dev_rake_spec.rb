require 'rails_helper'
require 'rake'

describe 'dev rake tasks' do
  include UspsIppHelper

  before do
    Rake.application.rake_require 'tasks/dev'
    Rake::Task.define_task(:environment)
    Rake::Task.define_task('db:setup')
  end

  describe 'dev:prime' do
    it 'runs successfully' do
      Rake::Task['dev:prime'].invoke

      expect(User.count).to eq 4
    end
  end

  context 'environment variables set' do
    prev_num_users = nil
    prev_progress = nil
    prev_enrollment_status = nil
    prev_verified = nil
    prev_scrypt_cost = nil
    prev_pending_in_usps = nil
    usps_request_delay_ms = nil
    max_num_attempts = nil

    before(:each) do
      allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
      max_num_attempts = ENV['MAX_NUM_ATTEMPTS']
      prev_enrollment_status = ENV['ENROLLMENT_STATUS']
      prev_num_users = ENV['NUM_USERS']
      prev_pending_in_usps = ENV['CREATE_PENDING_ENROLLMENT_IN_USPS']
      prev_progress = ENV['PROGRESS']
      prev_scrypt_cost = ENV['SCRYPT_COST']
      prev_verified = ENV['VERIFIED']
      usps_request_delay_ms = ENV['USPS_REQUEST_DELAY_MS']

      ENV['PROGRESS'] = 'no'
      ENV['NUM_USERS'] = '10'
      ENV['SCRYPT_COST'] = '800$8$1$'
      ENV['VERIFIED'] = nil
      Rake::Task['dev:random_users'].reenable
    end

    after(:each) do
      ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = prev_pending_in_usps
      ENV['ENROLLMENT_STATUS'] = prev_enrollment_status
      ENV['MAX_NUM_ATTEMPTS'] = max_num_attempts
      ENV['NUM_USERS'] = prev_num_users
      ENV['PROGRESS'] = prev_progress
      ENV['SCRYPT_COST'] = prev_scrypt_cost
      ENV['USPS_REQUEST_DELAY_MS'] = usps_request_delay_ms
      ENV['VERIFIED'] = prev_verified
    end

    describe 'dev:random_users' do
      it 'runs successfully' do
        ENV['VERIFIED'] = 'yes'

        expect(User.count).to eq 0

        Rake::Task['dev:random_users'].invoke

        expect(User.count).to eq 10
        expect(User.first.active_profile).to be_a Profile
      end

      it 'skips previously added users' do
        ENV['NUM_USERS'] = '5'

        expect(User.count).to eq 0

        Rake::Task['dev:random_users'].invoke

        expect(User.count).to eq 5

        ENV['NUM_USERS'] = '10'

        Rake::Task['dev:random_users'].reenable
        Rake::Task['dev:random_users'].invoke

        expect(User.count).to eq 10
      end

      it 'skips previously verified users' do
        ENV['VERIFIED'] = 'yes'
        ENV['NUM_USERS'] = '5'

        expect(User.count).to eq 0

        Rake::Task['dev:random_users'].invoke

        verified_user = User.last
        verified_user_updated_at = verified_user.updated_at
        verified_user_profile = verified_user.active_profile
        expect(verified_user_profile).to be_instance_of(Profile)

        expect(User.count).to eq 5

        ENV['VERIFIED'] = nil
        ENV['NUM_USERS'] = '10'

        Rake::Task['dev:random_users'].reenable
        Rake::Task['dev:random_users'].invoke

        expect(User.count).to eq 10
        verified_user.reload
        expect(verified_user.updated_at).to eq(verified_user_updated_at)
        expect(verified_user.active_profile).to be(verified_user_profile)

        unverified_user = User.last
        expect(unverified_user.active_profile).to be_nil

        ENV['VERIFIED'] = 'yes'

        Rake::Task['dev:random_users'].reenable
        Rake::Task['dev:random_users'].invoke

        expect(User.count).to eq 10

        unverified_user = User.last
        expect(unverified_user.active_profile).to be_instance_of(Profile)

        verified_user.reload
        expect(verified_user.updated_at).to eq(verified_user_updated_at)
        expect(verified_user.active_profile).to be(verified_user_profile)
      end
    end

    describe 'dev:random_in_person_users' do
      before(:each) do
        ENV['VERIFIED'] = nil
        Rake::Task['dev:random_in_person_users'].reenable
      end

      it 'runs successfully, defaults to pending' do
        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.pending.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'pending',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),
          'enrollment_code' => an_instance_of(String),
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(false)
      end

      it 'skips previously added pending enrollments' do
        ENV['NUM_USERS'] = '5'
        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 5
        expect(InPersonEnrollment.count).to eq 5
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 5
        expect(InPersonEnrollment.pending.count).to eq 5

        first_batch_last_updated = InPersonEnrollment.last
        first_batch_last_updated_id = first_batch_last_updated.id
        first_batch_last_updated_at = first_batch_last_updated.updated_at

        expect(first_batch_last_updated_at).to respond_to(:to_date)

        ENV['NUM_USERS'] = '10'

        Rake::Task['dev:random_users'].reenable
        Rake::Task['dev:random_in_person_users'].reenable
        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.pending.count).to eq 10

        expect(
          InPersonEnrollment.find(first_batch_last_updated_id).updated_at,
        ).to eq(first_batch_last_updated_at)

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'pending',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),
          'enrollment_code' => an_instance_of(String),
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(false)
      end

      it 'can create establishing enrollments' do
        ENV['ENROLLMENT_STATUS'] = 'establishing'

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.establishing.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'establishing',
        )
        expect(last_record.profile).to be_nil
      end

      it 'can create cancelled enrollments' do
        ENV['ENROLLMENT_STATUS'] = 'cancelled'

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.cancelled.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'cancelled',
        )
        expect(last_record.profile).to be_nil
      end

      it 'can create expired enrollments' do
        ENV['ENROLLMENT_STATUS'] = 'expired'

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.expired.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'expired',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),
          'enrollment_code' => an_instance_of(String),
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(false)
      end

      it 'can create failed enrollments' do
        ENV['ENROLLMENT_STATUS'] = 'failed'

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.failed.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'failed',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),
          'enrollment_code' => an_instance_of(String),
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(false)
      end

      it 'can create passed enrollments' do
        ENV['ENROLLMENT_STATUS'] = 'passed'

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.passed.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'passed',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),
          'enrollment_code' => an_instance_of(String),
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(true)
      end

      it 'creates the enrollment in USPS IPPaaS when CREATE_PENDING_ENROLLMENT_IN_USPS is truthy' do
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        stub_request_token
        stub_request_enroll

        expect(User.count).to eq 0
        expect(InPersonEnrollment.count).to eq 0

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 10
        expect(InPersonEnrollment.distinct.count('user_id')).to eq 10
        expect(InPersonEnrollment.pending.count).to eq 10

        # Spot check attributes on last record
        last_record = InPersonEnrollment.last
        expect(last_record.attributes).to include(
          'status' => 'pending',
          'enrollment_established_at' => respond_to(:to_date),
          'unique_id' => an_instance_of(String),

          # Check for the enrollment code in the stubbed response
          'enrollment_code' => '2048702198804353',
        )
        expect(last_record.profile).to be_instance_of(Profile)
        expect(last_record.profile.active).to be(false)
      end

      it 'waits between USPS IPPaaS requests when USPS_REQUEST_DELAY_MS is set' do
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        ENV['USPS_REQUEST_DELAY_MS'] = '200'
        stub_request_token
        stub_request_enroll

        expect_any_instance_of(Object).to receive(:sleep).exactly(10).times.with(0.2)

        Rake::Task['dev:random_in_person_users'].invoke
      end

      it 'retries when it gets an error from USPS' do
        ENV['NUM_USERS'] = '1'
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        stub_request_token
        # Stub the requests to timeout twice and then succeed
        stub_request(
          :post,
          %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
        ).to_raise(Faraday::TimeoutError).times(2).then.
          to_return(
            status: 200,
            body: UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
            headers: { 'content-type' => 'application/json' },
          ).times(1)

        expect(UspsInPersonProofing::EnrollmentHelper).
          to receive(:schedule_in_person_enrollment).and_call_original.exactly(3).times
        expect(Rails.logger).to receive(:error).
          with('Exception raised while enrolling user: Exception from WebMock').exactly(2).times

        Rake::Task['dev:random_in_person_users'].invoke

        expect(User.count).to eq 1
        expect(InPersonEnrollment.count).to eq 1
        expect(InPersonEnrollment.pending.count).to eq 1
      end

      it 'stops retrying after MAX_NUM_ATTEMPTS attempts and fails the transaction' do
        ENV['MAX_NUM_ATTEMPTS'] = '5'
        ENV['NUM_USERS'] = '10'
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        stub_request_token
        # Allow one enrollment to succeed and then timeout three times
        stub_request(
          :post,
          %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
        ).
          to_return(
            status: 200,
            body: UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
            headers: { 'content-type' => 'application/json' },
          ).
          then.to_raise(Faraday::TimeoutError).times(5)

        expect(UspsInPersonProofing::EnrollmentHelper).
          to receive(:schedule_in_person_enrollment).and_call_original.exactly(6).times
        expect(Rails.logger).to receive(:error).
          with('Exception raised while enrolling user: Exception from WebMock').exactly(5).times

        expect do
          Rake::Task['dev:random_in_person_users'].invoke
        end.to raise_error(UspsInPersonProofing::Exception::RequestEnrollException)

        expect(User.count).to eq 10
        expect(InPersonEnrollment.count).to eq 0
        expect(InPersonEnrollment.pending.count).to eq 0
      end

      it 'defaults to MAX_NUM_ATTEMPTS=3 if not specified' do
        ENV['NUM_USERS'] = '10'
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        stub_request_token
        # Allow one enrollment to succeed and then timeout three times
        stub_request(
          :post,
          %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
        ).
          to_return(
            status: 200,
            body: UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
            headers: { 'content-type' => 'application/json' },
          ).
          then.to_raise(Faraday::TimeoutError).times(3)

        expect(UspsInPersonProofing::EnrollmentHelper).
          to receive(:schedule_in_person_enrollment).and_call_original.exactly(4).times
        expect(Rails.logger).to receive(:error).
          with('Exception raised while enrolling user: Exception from WebMock').exactly(3).times

        expect do
          Rake::Task['dev:random_in_person_users'].invoke
        end.to raise_error(UspsInPersonProofing::Exception::RequestEnrollException)
      end

      it 'waits USPS_REQUEST_DELAY_MS ms between retries' do
        ENV['NUM_USERS'] = '1'
        ENV['CREATE_PENDING_ENROLLMENT_IN_USPS'] = '1'
        ENV['USPS_REQUEST_DELAY_MS'] = '200'
        stub_request_token
        # Stub the requests to timeout twice and then succeed
        stub_request(
          :post,
          %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
        ).to_raise(Faraday::TimeoutError).times(2).then.
          to_return(
            status: 200,
            body: UspsInPersonProofing::Mock::Fixtures.request_enroll_response,
            headers: { 'content-type' => 'application/json' },
          ).times(1)
        expect(UspsInPersonProofing::EnrollmentHelper).
          to receive(:schedule_in_person_enrollment).and_call_original.exactly(3).times
        expect_any_instance_of(Object).to receive(:sleep).exactly(3).times.with(0.2)

        Rake::Task['dev:random_in_person_users'].invoke
      end
    end
  end
end
