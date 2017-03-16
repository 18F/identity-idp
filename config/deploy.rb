require 'net/ssh/proxy/command'

#################
# GLOBAL CONFIG
#################
set :application, 'idp'
set :assets_roles, [:app, :web]
# set branch based on env var or ask with the default set to the current local branch
set :branch, ENV['branch'] || ENV['BRANCH'] || ask(:branch, `git branch`.match(/\* (\S+)\s/m)[1])
set :bundle_without, 'deploy development doc test'
set :deploy_to, '/srv/idp'
set :deploy_via, :remote_cache
set :keep_releases, 5
set :linked_files, %w(certs/saml.crt
                      config/application.yml
                      config/database.yml
                      config/newrelic.yml
                      keys/equifax_rsa
                      keys/saml.key.enc)
set :linked_dirs, %w(bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system)
set :passenger_roles, [:web]
set :passenger_restart_wait, 5
set :passenger_restart_runner, :sequence
set :rails_env, :production
set :repo_url, 'https://github.com/18F/identity-idp.git'
set :sidekiq_options, ''
set :sidekiq_queue, [:analytics, :mailers, :sms, :voice]
set :sidekiq_monit_use_sudo, true
set :sidekiq_user, 'ubuntu'
set :whenever_roles, [:job_creator]
set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }
set :tmp_dir, '/tmp'

set :bastion_user, ENV['BASTION_USER'] || 'ubuntu'
set :ssh_options do
  ssh_command = "ssh -A #{fetch(:bastion_user)}@#{fetch(:bastion_host)} -W %h:%p"
  {
    proxy: Net::SSH::Proxy::Command.new(ssh_command),
    user: 'ubuntu',
  }
end

server 'idp1-0', roles: %w(web db)
server 'idp2-0', roles: %w(web)
server 'worker', roles: %w(app job_creator)

#########
# TASKS
#########
# rubocop:disable Metrics/BlockLength
namespace :deploy do
  desc 'Install npm packages required for asset compilation with browserify'
  task :browserify do
    on roles(:app, :web), in: :sequence do
      within release_path do
        execute :npm, 'install'
      end
    end
  end

  desc 'Write deploy information to deploy.json'
  task :deploy_json do
    on roles(:app, :web), in: :parallel do
      require 'stringio'

      within current_path do
        deploy = {
          env: fetch(:stage),
          branch: fetch(:branch),
          user: fetch(:local_user),
          sha: fetch(:current_revision),
          timestamp: fetch(:release_timestamp),
        }

        execute :mkdir, '-p', 'public/api'

        # the #upload! method does not honor the values of #within at the moment
        # https://github.com/capistrano/sshkit/blob/master/EXAMPLES.md#upload-a-file-from-a-stream
        upload! StringIO.new(deploy.to_json), "#{current_path}/public/api/deploy.json"

        execute :chmod, '+r', 'public/api/deploy.json'
      end
    end
  end

  desc 'Modify permissions on /srv/idp'
  task :mod_perms do
    on roles(:web), in: :parallel do
      execute :sudo, :chown, '-R', 'ubuntu:nogroup', deploy_to
    end
  end

  desc 'Clean NPM cache'
  task :clean_npm_cache do
    on roles(:app, :web), in: :parallel do
      execute :npm, 'cache clean'
    end
  end

  before 'assets:precompile', :browserify
  after 'deploy:updated', 'newrelic:notice_deployment'
  after 'deploy:log_revision', :deploy_json
  after 'deploy', 'deploy:mod_perms'
end
# rubocop:enable Metrics/BlockLength
