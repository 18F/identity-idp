require 'rails_helper'

RSpec.describe 'db:check_for_sensitive_columns' do
  before :all do
    Rake.application.rake_require 'tasks/column_comment_checker'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['db:check_for_sensitive_columns'] }

  it 'checks for columns with sensitivity comments' do
    expect { task.execute }.to output(/All columns have sensitivity comments./).to_stdout
  end

  context 'when a column is missing a sensitivity comment' do
    before do
      ActiveRecord::Base.connection.add_column :users, :test_col, :string
    end

    after do
      ActiveRecord::Base.connection.remove_column :users, :test_col
    end

    it 'aborts with missing columns' do
      result = task.execute
      expect { result }.to output(/Columns with sensitivity comments found:/).to_stdout
      expect { result }.to output(/users#test_col/).to_stdout
      expect { result }.to raise_error(SystemExit) do |error|
        expect(error.message).to eq('Aborting due to columns with missing sensitivity comments.')
      end
    end
  end
end
