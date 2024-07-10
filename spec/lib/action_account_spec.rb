require 'rails_helper'
require 'tableparser'
require 'action_account'

RSpec.describe ActionAccount do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:argv) { [] }

  subject(:action_account) { ActionAccount.new(argv:, stdout:, stderr:) }

  describe 'command line run' do
    let(:argv) { ['review-pass', user.uuid, '--reason', 'INV1234'] }
    let(:user) { create(:user) }

    it 'logs UUIDs and the command name to STDERR formatted for Slack', aggregate_failures: true do
      action_account.run

      expect(stderr.string).to include('`review-pass`')
      expect(stderr.string).to include("`#{user.uuid}`")
    end

    context 'when the command cannot be performed successfully' do
      let(:user) { create(:user, :fraud_review_pending) }
      it 'logs Messages to STDERR formatted for Slack' do
        user.fraud_review_pending_profile.update!(fraud_review_pending_at: 31.days.ago)

        action_account.run

        expect(stderr.string).to eq(<<~STR)
          *Task*: `review-pass`
          *UUIDs*: `#{user.uuid}`
          *Messages*:
              • `#{user.uuid}`: User is past the 30 day review eligibility.
        STR
      end
    end

    context 'with command line flags' do
      describe '--help' do
        before { argv << '--help' }
        it 'prints a help message' do
          action_account.run

          expect(stdout.string).to include('Options:')
        end

        it 'prints help to stderr', aggregate_failures: true do
          action_account.run

          expect(stderr.string).to include('*Task*: `help`')
          expect(stderr.string).to include('*UUIDs*: N/A')
        end
      end

      describe '--csv' do
        before { argv << '--csv' }
        it 'formats output as CSV' do
          action_account.run

          expect(CSV.parse(stdout.string)).to eq(
            [
              ['uuid', 'status', 'reason'],
              [user.uuid, 'Error: User does not have a pending fraud review', 'INV1234'],
            ],
          )
        end
      end

      describe '--table' do
        before { argv << '--table' }
        it 'formats output as an ASCII table' do
          action_account.run

          expect(Tableparser.parse(stdout.string)).to eq(
            [
              ['uuid', 'status', 'reason'],
              [user.uuid, 'Error: User does not have a pending fraud review', 'INV1234'],
            ],
          )
        end
      end

      describe '--json' do
        before { argv << '--json' }
        it 'formats output as JSON' do
          action_account.run

          expect(JSON.parse(stdout.string)).to eq(
            [
              {
                'uuid' => user.uuid,
                'status' => 'Error: User does not have a pending fraud review',
                'reason' => 'INV1234',
              },
            ],
          )
        end
      end

      describe '--include-missing' do
        let(:argv) do
          ['review-reject', 'does_not_exist@example.com', '--include-missing', '--json']
        end
        it 'adds rows for missing values' do
          action_account.run

          expect(JSON.parse(stdout.string)).to eq(
            [
              {
                'uuid' => 'does_not_exist@example.com',
                'status' => 'Error: Could not find user with that UUID',
                'reason' => nil,
              },
            ],
          )
        end
      end

      describe '--no-include-missing' do
        let(:argv) do
          ['review-reject', 'does_not_exist@example.com', '--no-include-missing', '--json']
        end
        it 'does not add rows for missing values' do
          action_account.run

          expect(JSON.parse(stdout.string)).to be_empty
        end
      end
    end
  end

  describe ActionAccount::ReviewReject do
    subject(:subtask) { ActionAccount::ReviewReject.new }

    describe '#run' do
      let(:user) { create(:profile, :fraud_review_pending).user }
      let(:user_without_profile) { create(:user) }

      let(:analytics) { FakeAnalytics.new }

      before do
        allow(Analytics).to receive(:new).and_return(analytics)
      end

      let(:args) { [user.uuid, user_without_profile.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
      subject(:result) { subtask.run(args:, config:) }

      it 'Reject a user that has a pending review', aggregate_failures: true do
        profile_fraud_review_pending_at = user.pending_profile.fraud_review_pending_at

        # rubocop:disable Layout/LineLength
        expect(result.table).to match_array(
          [
            ['uuid', 'status', 'reason'],
            [user.uuid, "User's profile has been deactivated due to fraud rejection.", 'INV1234'],
            [user_without_profile.uuid, 'Error: User does not have a pending fraud review', 'INV1234'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID', 'INV1234'],
          ],
        )
        # rubocop:enable Layout/LineLength

        expect(result.subtask).to eq('review-reject')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])

        expect(analytics).to have_logged_event(
          'Fraud: Profile review rejected',
          success: true,
          errors: nil,
          exception: nil,
          profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        )
        expect(analytics).to have_logged_event(
          'Fraud: Profile review rejected',
          success: false,
          errors: { message: 'Error: User does not have a pending fraud review' },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
        expect(analytics).to have_logged_event(
          'Fraud: Profile review rejected',
          success: false,
          errors: { message: 'Error: Could not find user with that UUID' },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
      end
    end
  end

  describe ActionAccount::ReviewPass do
    subject(:subtask) { ActionAccount::ReviewPass.new }

    describe '#run' do
      let(:user) { create(:profile, :fraud_review_pending).user }
      let(:user_without_profile) { create(:user) }

      let(:analytics) { FakeAnalytics.new }

      before do
        allow(Analytics).to receive(:new).and_return(analytics)
      end

      let(:args) { [user.uuid, user_without_profile.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
      subject(:result) { subtask.run(args:, config:) }

      it 'Pass a user that has a pending review', aggregate_failures: true do
        profile_fraud_review_pending_at = user.pending_profile.fraud_review_pending_at

        # rubocop:disable Layout/LineLength
        expect(result.table).to match_array(
          [
            ['uuid', 'status', 'reason'],
            [user.uuid, "User's profile has been activated and the user has been emailed.", 'INV1234'],
            [user_without_profile.uuid, 'Error: User does not have a pending fraud review', 'INV1234'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID', 'INV1234'],
          ],
        )
        # rubocop:enable Layout/LineLength

        expect(result.subtask).to eq('review-pass')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])

        expect(analytics).to have_logged_event(
          'Fraud: Profile review passed',
          success: true,
          errors: nil,
          exception: nil,
          profile_fraud_review_pending_at: profile_fraud_review_pending_at,
        )
        expect(analytics).to have_logged_event(
          'Fraud: Profile review passed',
          success: false,
          errors: { message: 'Error: User does not have a pending fraud review' },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
        expect(analytics).to have_logged_event(
          'Fraud: Profile review passed',
          success: false,
          errors: { message: 'Error: Could not find user with that UUID' },
          exception: nil,
          profile_fraud_review_pending_at: nil,
        )
      end
    end
  end

  describe ActionAccount::SuspendUser do
    subject(:subtask) { ActionAccount::SuspendUser.new }

    describe '#run' do
      let(:user) { create(:user) }
      let(:suspended_user) { create(:user, :suspended) }
      let(:reinstated_user) { create(:user, :reinstated) }
      let(:args) { [user.uuid, suspended_user.uuid, reinstated_user.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
      subject(:result) { subtask.run(args:, config:) }

      it 'suspend a user that is not suspended already', aggregate_failures: true do
        expect(result.table).to match_array(
          [
            ['uuid', 'status', 'reason'],
            [user.uuid, 'User has been suspended', 'INV1234'],
            [suspended_user.uuid, 'User has already been suspended', 'INV1234'],
            [reinstated_user.uuid, 'User has been suspended', 'INV1234'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID', 'INV1234'],
          ],
        )

        expect(result.subtask).to eq('suspend-user')
        expect(result.uuids).to match_array([user.uuid, suspended_user.uuid, reinstated_user.uuid])
      end
    end
  end

  describe ActionAccount::ReinstateUser do
    subject(:subtask) { ActionAccount::ReinstateUser.new }

    describe '#run' do
      let(:user) { create(:user) }
      let(:suspended_user) { create(:user, :suspended) }
      let(:args) { [user.uuid, suspended_user.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
      subject(:result) { subtask.run(args:, config:) }

      it 'suspends users that are not suspended already', aggregate_failures: true do
        expect { result }.to(change { ActionMailer::Base.deliveries.count }.by(1))

        # rubocop:disable Layout/LineLength
        expect(result.table).to match_array(
          [
            ['uuid', 'status', 'reason'],
            [user.uuid, 'User is not suspended', 'INV1234'],
            [suspended_user.uuid, 'User has been reinstated and the user has been emailed', 'INV1234'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID', 'INV1234'],
          ],
        )
        # rubocop:enable Layout/LineLength

        expect(result.subtask).to eq('reinstate-user')
        expect(result.uuids).to match_array([user.uuid, suspended_user.uuid])
      end

      context 'with a reinstated user' do
        let(:user) { create(:user, :reinstated) }
        let(:args) { [user.uuid] }

        it 'gives a helpful error if the user has been reinstated' do
          message = "User has already been reinstated (at #{user.reinstated_at})"
          expect(result.table).to match_array(
            [
              ['uuid', 'status', 'reason'],
              [user.uuid, message, 'INV1234'],
            ],
          )
        end
      end
    end
  end

  describe ActionAccount::ConfirmSuspendUser do
    subject(:subtask) { ActionAccount::ConfirmSuspendUser.new }

    describe '#run' do
      let(:user) { create(:user) }
      let(:suspended_user) { create(:user, :suspended) }
      let(:args) { [suspended_user.uuid, user.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:, reason: 'INV1234') }
      subject(:result) { subtask.run(args:, config:) }

      let(:analytics) { FakeAnalytics.new }

      before do
        allow(subtask).to receive(:analytics).and_return(analytics)
      end

      it 'emails users that are suspended', aggregate_failures: true do
        expect { result }.to(change { ActionMailer::Base.deliveries.count }.by(1))

        expect(result.table).to match_array(
          [
            ['uuid', 'status', 'reason'],
            [suspended_user.uuid, 'User has been emailed', 'INV1234'],
            [user.uuid, 'User is not suspended', 'INV1234'],
            ['uuid-does-not-exist', 'Error: Could not find user with that UUID', 'INV1234'],
          ],
        )

        expect(result.subtask).to eq('confirm-suspend-user')
        expect(result.uuids).to match_array([user.uuid, suspended_user.uuid])

        expect(analytics).to have_logged_event(:user_suspension_confirmed)
      end
    end
  end
end
