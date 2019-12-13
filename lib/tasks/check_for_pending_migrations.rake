namespace :db do
  desc 'Raise an error if migrations are pending'
  task check_for_pending_migrations: :environment do
    instance_role_filename = '/etc/login.gov/info/role'
    instance_role = File.exist?(instance_role_filename) &&
                    File.read(instance_role_filename).strip

    begin
      domain = File.read('/etc/login.gov/info/domain').strip
    rescue Errno::ENOENT
      domain = nil
    end

    if instance_role == 'migration'
      warn('Skipping pending migration check on migration instance')
    else
      begin
        ActiveRecord::Migration.check_pending!(ActiveRecord::Base.connection)
      rescue ActiveRecord::NoDatabaseError => err
        # This error occurs when the database does not exist.
        # In personal test environments, that's OK, we should continue and run
        # database migrations.
        # In production, this should never happen, so we should bail out.
        raise if domain == 'login.gov'

        warn('Could not check for migrations. Database does not exist:')
        warn(err.inspect)
      end
    end
  end
end
