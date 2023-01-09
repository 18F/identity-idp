require 'rails_helper'
require 'rake'

describe 'review_profile' do
  let(:user) { create(:user, :deactivated_threatmetrix_profile) }
  let(:task_name) { nil }

  subject(:invoke_task) do
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke
  end

  before do
    Rake.application.rake_require('lib/tasks/review_profile', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
    allow(STDIN).to receive(:getpass) { user.uuid }
  end

  describe 'users:review:pass' do
    let(:task_name) { 'users:review:pass' }

    it 'activates the users profile' do
      invoke_task
      expect(user.reload.profiles.first.active).to eq(true)
    end

    it 'dispatches account verified alert' do
      freeze_time do
        expect(UserAlerts::AlertUserAboutAccountVerified).to receive(:call).with(
          user: user,
          date_time: Time.zone.now,
          disavowal_token: kind_of(String),
          sp_name: nil,
        )
        invoke_task
      end
    end
  end

  describe 'users:review:reject' do
    let(:task_name) { 'users:review:reject' }

    it 'deactivates the users profile with reason threatmetrix_review_rejected' do
      invoke_task
      expect(user.reload.profiles.first.deactivation_reason).to eq('threatmetrix_review_rejected')
    end
  end
end
