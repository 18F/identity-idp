require 'rails_helper'
require 'rake'

RSpec.describe 'check for pending migrations rake tasks' do
  before do
    Rake.application.rake_require 'tasks/check_for_pending_migrations'
    Rake::Task.define_task(:environment)
  end

  describe 'db:check_for_pending_migrations' do
    it 'runs successfully' do
      Rake::Task['db:check_for_pending_migrations'].invoke
    end
  end
end
