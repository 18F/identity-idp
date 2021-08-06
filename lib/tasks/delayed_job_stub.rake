namespace :jobs do
  desc 'a command that stubs out delayed_job and runs good_job instead, for a smooth transition'
  task work: :environment do
    exec 'bundle exec good_job start'
  end
end
