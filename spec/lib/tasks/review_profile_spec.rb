require 'rails_helper'
require 'rake'

RSpec.describe 'review_profile' do
  let(:user) { create(:user, :fraud_review_pending) }
  let(:uuid) { user.uuid }
  let(:task_name) { nil }

  subject(:invoke_task) do
    Rake::Task[task_name].reenable
    Rake::Task[task_name].invoke
  end

  let(:stdout) { StringIO.new }

  before do
    Rake.application.rake_require('lib/tasks/review_profile', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
    allow(STDIN).to receive(:gets).and_return(
      "John Doe\n",
      "Rspec Test\n",
      uuid,
    )
    stub_const('STDOUT', stdout)
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
          sp_name: nil,
        )
        invoke_task
      end
    end

    context 'when the user does not exist' do
      let(:user) { nil }
      let(:uuid) { 'not-a-real-uuid' }

      it 'prints an error' do
        invoke_task

        expect(stdout.string).to include('Error: Could not find user with that UUID')
      end
    end

    context 'when the user has cancelled verification' do
      it 'does not activate the profile' do
        user.profiles.first.update!(gpo_verification_pending_at: user.created_at)

        expect { invoke_task }.to raise_error(RuntimeError)

        expect(user.reload.profiles.first.active).to eq(false)
      end
    end
  end

  describe 'users:review:reject' do
    let(:task_name) { 'users:review:reject' }

    it 'deactivates the users profile with reason threatmetrix_review_rejected' do
      invoke_task
      expect(user.reload.profiles.first.active).to eq(false)
      expect(user.reload.profiles.first.fraud_rejection?).to eq(true)
    end

    it 'sends the user an email about their account deactivation' do
      expect { invoke_task }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    context 'when the user does not exist' do
      let(:user) { nil }
      let(:uuid) { 'not-a-real-uuid' }

      it 'prints an error' do
        invoke_task

        expect(stdout.string).to include('Error: Could not find user with that UUID')
      end
    end

    context 'when the user profile has a nil fraud_review_pending_at' do
      let(:user) do
        create(
          :user,
          :with_pending_in_person_enrollment,
          proofing_component: build(:proofing_component),
        )
      end

      it 'prints an error' do
        invoke_task

        expect(stdout.string).to include('Error: User does not have a pending fraud review')
      end
    end
  end
end
