# frozen_string_literal: true

namespace :data do
  desc 'Remove deprecated redis set idv:socure:users'
  task remove_socure_users: :environment do
    set_name = 'idv:socure:users'
    total_socure_users = REDIS_POOL.with { |r| r.scard(set_name) }
    puts "Removing #{set_name} set with #{total_socure_users} users"
    REDIS_POOL.with { |r| puts r.unlink(set_name) }
    exists = REDIS_POOL.with { |r| r.exists?(set_name) }
    puts "#{set_name} exists after deletion? #{exists}"
  end
end
