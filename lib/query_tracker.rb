require 'pg_query'

# Tracks queries by table
# Intended for tests, not for production
class QueryTracker
  # @yield block to track queries during
  # @return [Hash<Symbol, Array<Array(:Symbol, String)>>] a hash of
  #   {table_name: [[:select, "source_location.rb:123"]]}
  def self.track
    queries = Hash.new { |h, k| h[k] = [] }

    subscriber = ActiveSupport::Notifications.
                 subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]

      action = sql.split(' ').first.downcase.to_sym
      tables = PgQuery.parse(sql).tables.map(&:to_sym)

      root = Rails.root.to_s
      location = caller.find do |line|
        line.include?(root) && Gem.path.none? { |v| line.include?(v) }
      end

      tables.each do |table|
        queries[table] << [action, location]
      end
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
