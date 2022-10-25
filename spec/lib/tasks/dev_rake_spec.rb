require 'rails_helper'
require 'rake'

describe 'dev rake tasks' do
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

  describe 'dev:random_users' do
    it 'runs successfully' do
      prev_num_users = ENV['NUM_USERS']
      ENV['NUM_USERS'] = '10'
      prev_verified = ENV['VERIFIED']
      ENV['VERIFIED'] = 'yes'
      prev_progress = ENV['PROGRESS']
      ENV['PROGRESS'] = 'no'

      expect(User.count).to eq 0

      Rake::Task['dev:random_users'].invoke

      expect(User.count).to eq 10
      expect(User.first.active_profile).to be_a Profile

      ENV['NUM_USERS'] = prev_num_users
      ENV['VERIFIED'] = prev_verified
      ENV['PROGRESS'] = prev_progress
    end
  end

  describe 'dev:enroll_random_users_in_person' do
    prev_num_users = nil
    prev_progress = nil
    prev_enrollment_status = nil
    before do
      prev_num_users = ENV['NUM_USERS']
      prev_progress = ENV['PROGRESS']
      prev_enrollment_status = ENV['ENROLLMENT_STATUS']
      ENV['NUM_USERS'] = '40'
      ENV['PROGRESS'] = 'no'
      Rake::Task['dev:random_users'].invoke
    end
    after do
      ENV['NUM_USERS'] = prev_num_users
      ENV['PROGRESS'] = prev_progress
      ENV['ENROLLMENT_STATUS'] = prev_enrollment_status
    end
    it 'runs successfully, defaults to pending' do
      ENV['NUM_USERS'] = '35'

      expect(InPersonEnrollment.count).to eq 0

      Rake::Task['dev:enroll_random_users_in_person'].invoke

      expect(InPersonEnrollment.count).to eq 35
      expect(InPersonEnrollment.distinct.count('user_id')).to eq 35
      expect(InPersonEnrollment.pending.count).to eq 35

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
      ENV['NUM_USERS'] = '35'
      ENV['ENROLLMENT_STATUS'] = 'establishing'

      expect(InPersonEnrollment.count).to eq 0

      Rake::Task['dev:enroll_random_users_in_person'].invoke

      expect(InPersonEnrollment.count).to eq 35
      expect(InPersonEnrollment.distinct.count('user_id')).to eq 35
      expect(InPersonEnrollment.establishing.count).to eq 35

      # Spot check attributes on last record
      last_record = InPersonEnrollment.last
      expect(last_record.attributes).to include(
        'status' => 'establishing',
      )
      expect(last_record.profile).to be_nil
    end
  end
end
