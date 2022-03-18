require 'pg_query'

# Tracks queries by table
# Intended for tests, not for production
class QueryTracker
  # @yield block to track queries during
  # @return [Hash<Symbol, Array<Array(:Symbol, String)>>] a hash of
  #   {table_name: [[:select, "query"]]}
  def self.track
    queries = Hash.new { |h, k| h[k] = [] }

    subscriber = ActiveSupport::Notifications.
      subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]

        action = sql.split(' ').first.downcase.to_sym
        tables = PgQuery.parse(sql).tables.map(&:to_sym)

        tables.each do |table|
          queries[table] << [action, sql]
        end
      end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
