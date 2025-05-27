require 'rails_helper'
require 'reporting/account_reset_report'

RSpec.describe Reporting::AccountResetReport do
  let(:time_range) { Date.new(2022, 1, 1).in_time_zone('UTC').all_month }

  subject(:report) { Reporting::AccountResetReport.new(time_range:) }

  before do
    stub_cloudwatch_logs(
      [
        # deletes account after being unable to authenticate
        { 'user_id' => 'user1', 'name' => 'Email and Password Authentication' },
        { 'user_id' => 'user1', 'name' => 'Account Reset: delete' },
        

        # deletes account after being unable to authenticate
        { 'user_id' => 'user2', 'name' => 'Email and Password Authentication' },
        { 'user_id' => 'user2', 'name' => 'Account Reset: delete' },
        

        # deletes account after being unable to authenticate
        { 'user_id' => 'user3', 'name' => 'Email and Password Authentication' },
        { 'user_id' => 'user3', 'name' => 'Account Reset: delete' },

        # unable to authenticate, but does not delete account
        { 'user_id' => 'user4', 'name' => 'Email and Password Authentication' },

        # unable to authenticate, but does not delete account
        { 'user_id' => 'user5', 'name' => 'Email and Password Authentication' },
      ],
    )
  end

  describe '#account_reset_rate_emailable_report' do
    let(:expected_report) do
        Reporting::EmailableReport.new(
          subtitle: 'Account Reset Rate',
          table: expected_table,
        )
    end
    it 'return expected table for email' do
      expect(report.account_reset_rate_emailable_report).to eq expected_report
    end
  end

  describe '#cloudwatch_client' do
    let(:opts) { {} }
    let(:subject) { described_class.new(time_range:, **opts) }
    let(:default_args) do
      {
        num_threads: 5,
        ensure_complete_logs: true,
        slice_interval: 3.hours,
        progress: false,
        logger: nil,
      }
    end

    describe 'when all args are default' do
      it 'creates a client with the default options' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when verbose is passed in' do
      let(:opts) { { verbose: true } }
      let(:logger) { double Logger }

      before do
        expect(Logger).to receive(:new).with(STDERR).and_return logger
        default_args[:logger] = logger
      end

      it 'creates a client with the expected logger' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when progress is passed in as true' do
      let(:opts) { { progress: true } }
      before { default_args[:progress] = true }

      it 'creates a client with progress as true' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when threads is passed in' do
      let(:opts) { { threads: 17 } }
      before { default_args[:num_threads] = 17 }

      it 'creates a client with the expected thread count' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end

    describe 'when slice is passed in' do
      let(:opts) { { slice: 2.weeks } }
      before { default_args[:slice_interval] = 2.weeks }

      it 'creates a client with expected time slice' do
        expect(Reporting::CloudwatchClient).to receive(:new).with(default_args)

        subject.cloudwatch_client
      end
    end
  end

  def expected_table(strings: false)
      [
        ['Accounts Reset', 'Authentication Attempts', 'Account Reset Rate'],
        [strings ? '3' : 3, strings ? '5' : 5, '60.0%'], 
      ]
  end
end
