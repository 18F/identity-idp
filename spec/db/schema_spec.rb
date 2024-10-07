require 'rails_helper'

RSpec.describe 'db:check_for_sensitive_columns' do
  around do |ex|
    ex.run
  rescue SystemExit
  end

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
      allow($stdout).to receive(:puts) # suppress output

      expect { task.invoke }.to raise_error(SystemExit)
      expect { task.invoke }.to output(/Columns with sensitivity comments found:/).to_stdout.
        and output(/users#test_col/).to_stdout
    end
  end
end
