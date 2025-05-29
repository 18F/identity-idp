require 'rails_helper'
require 'rake'

RSpec.describe 'duplicate accounts rake task' do
  before do
    Rake.application.rake_require 'tasks/duplicate_accounts'
    Rake::Task.define_task(:environment)
    Rake::Task['duplicate_accounts:report'].reenable
  end

  describe 'duplicate_accounts:report' do
    let(:service_provider) { ['test_saml_sp_requesting_signed_response_message'] }
    subject(:task) { Rake.application.invoke_task('duplicate_accounts:report[service_provider]') }

    context 'with an empty report array' do
      it 'displays a no results found message' do
        expect { task }.to \
          output("no results found\n").to_stdout
      end
    end

    context 'with a duplicate account shown in report array' do
      let(:results) do
        [
          {
            uuid: 'abc123def456',
            service_provider: service_provider[0],
            friendly_name: 'AAA Test SP',
            latest_activity: Date.yesterday.middle_of_day,
            activated_at: Date.yesterday.beginning_of_day,
          },
        ]
      end
      it 'displays a result' do
        allow(DuplicateAccountsReport).to receive(:call)
          .and_return(results)

        expect { task }.to \
          output(include('result to csv')).to_stdout
      end
    end
  end
end
