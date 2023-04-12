# id columns are generated as bigint, and we sometimes use constraint-less integer columns
# that reference another table. To ensure we use bigint for those columns, this check raises
# if a column is added that uses :integer and the column_name ends with "_id".
#
# Some "_id" columns may not be references to other tables and may not need to be bigint.
# To exclude a table/column from this check add a `[table, column]` item into excluded_columns:
#
# Ex: excluded_columns = [[:users, :my_new_id]]
class IdpStrongMigrations
  EXCLUDED_COLUMNS = [].freeze
end

StrongMigrations.add_check do |method, (table, column, type, _options)|
  is_excluded = IdpStrongMigrations::EXCLUDED_COLUMNS.include?([table, column])
  if !is_excluded && method == :add_column && column.to_s.ends_with?('_id') && type == :integer
    stop! """
    Columns referencing another table should use :bigint instead of integer.

    add_column #{table.inspect}, #{column.inspect}, :bigint
    OR
    t.bigint #{column.inspect}
    """
  end
end

# So we can run db:migrate during CI to verify migrations
StrongMigrations.start_after = 20190126105161

# Added to run tests locally; the defaults cause timeouts when setting things up. J.A.M.
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour
