# id columns are generated as bigint, and we sometimes use constraint-less integer columns
# that reference another table. To ensure we use bigint for those columns, this check raises
# if a column is added that uses :integer and the column_name ends with "_id".
#
# Some "_id" columns may not be references to other tables and may not need to be bigint.
# To exclude a table/column from this check add a `[table, column]` item into excluded_columns:
#
# Ex: excluded_columns = [[:users, :my_new_id]]

excluded_columns = []

StrongMigrations.add_check do |method, (table, column, type, _options)|
  excluded = excluded_columns.include?([table, column])
  if !excluded && method == :add_column && column.to_s.ends_with?('_id') && type == :integer
    stop! """
    Columns referencing another table should use :bigint instead of integer.

    add_column #{table.inspect}, #{column.inspect}, :bigint
    OR
    t.bigint #{column.inspect}
    """
  end
end
