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

      expect(User.count).to eq 2
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
end
