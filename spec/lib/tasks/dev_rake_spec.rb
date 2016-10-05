require 'rails_helper'
require 'rake'

describe 'dev:prime' do
  it 'runs successfully' do
    Rake.application.rake_require('lib/tasks/dev', [Rails.root.to_s])
    Rake::Task.define_task(:environment)
    Rake::Task.define_task('db:setup')

    Rake::Task['dev:prime'].invoke

    expect(User.count).to eq 2
  end
end
