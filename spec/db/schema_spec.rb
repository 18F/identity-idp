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
      ActiveRecord::Base.connection.add_column :users, :test_column, :string
    end

    after do
      ActiveRecord::Base.connection.remove_column :users, :test_column
    end

    it 'displays the missing column directions' do
      expect { task.execute }.to output(
        /In your migration, add 'comment: sensitive=false'\(or true for sensitive data\)/,
      ).to_stdout
    end
  end
end
