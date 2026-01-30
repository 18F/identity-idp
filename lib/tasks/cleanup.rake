namespace :data do
  desc 'Remove deprecated redis set idv:socure:users'
  task remove_socure_users: :environment do
    total_socure_users = REDIS_POOL.with { |r| r.scard('idv:socure:users') }
    puts "Removing idv:socure:users set with #{total_socure_users} users"
    REDIS_POOL.with { |r| puts r.del('idv:socure:users') }
    exists = REDIS_POOL.with { |r| r.exists?('idv:socure:users') }
    puts "idv:socure:users exists after deletion? #{exists}"
  end
end
