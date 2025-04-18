require 'rails_helper'
require 'rake'

RSpec.describe 'duplicate accounts rake task' do
  before do
    Rake.application.rake_require 'tasks/duplicate_accounts'
    Rake::Task.define_task(:environment)
  end

  describe 'duplicate_accounts:report' do
    let(:task) { 'duplicate_accounts:report' }

    context 'with an empty report array' do
      it 'displays a no results found message' do
        expect { Rake::Task[task].invoke }.to \
          output("no results found\n").to_stdout
      end
    end
  end
end
