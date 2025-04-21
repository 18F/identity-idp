require 'rails_helper'
require 'rake'

RSpec.describe 'duplicate accounts rake task' do
  before do
    Rake.application.rake_require 'tasks/duplicate_accounts'
    Rake::Task.define_task(:environment)
  end

  describe 'duplicate_accounts:report' do
    context 'with an empty report array' do
      let(:task) { 'duplicate_accounts:report' }
      it 'displays a no results found message' do
        expect { Rake::Task[task].invoke }.to \
          output("no results found\n").to_stdout
      end
    end

    context 'with a duplicate account shown in report array' do
      let(:task) { 'duplicate_accounts:report' }
      let(:results) do
        [
          {
            uuid: 'abc123def456',
            service_provider: 'AAA:Test:SP:localhost',
            friendly_name: 'AAA Test SP',
            latest_activity: Date.yesterday.middle_of_day,
            activated_at: Date.yesterday.beginning_of_day,
          },
        ]
      end
      it 'displays a result' do
        expect { Rake::Task[task].invoke }.to \
          output("result to csv\n").to_stdout
      end
    end
  end
end
