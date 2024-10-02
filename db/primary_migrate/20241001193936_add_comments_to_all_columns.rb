class AddCommentsToAllColumns < ActiveRecord::Migration[7.1]
  require 'yaml'

  def change

    yaml_data = YAML.load_file(
      Rails.root.join('config', 'sensitive_column_comments.yml'),
    )

    ## Set statement timeout to 1 hour
    ActiveRecord::Base.connection.execute('SET statement_timeout = 3600000')
    existing_tables = ActiveRecord::Base.connection.execute <<~SQL
      SELECT table_name 
      FROM information_schema.tables
      WHERE table_schema = 'public' and (table_name not like 'pg_%' or table_name not like 'sql_%' or table_name not like 'ar_%' or table_name not like 'schema_%' )
      ORDER BY table_name
    SQL
    existing_tables.each do |table|
      puts "Table: #{table['table_name']}"
      existing_columns = ActiveRecord::Base.connection.execute <<~SQL
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = '#{table['table_name']}'
        ORDER BY ordinal_position
      SQL
      existing_columns.each do |column|
        puts "  Column: #{column['column_name']}"
        is_sensitive = yaml_data.dig(table['table_name'], column['column_name']) ? 'sensitive: true': 'sensitive: false'
        if is_sensitive
          add_column_comment(table['table_name'], column['column_name'], is_sensitive)
        end
      end
    end
  end

  private
  
  def add_column_comment(table_name, column_name, comment)
    #verify if there is comment already on table or column
    #if there is comment on column, then append the new comment to the existing comment
    existing_comment = ActiveRecord::Base.connection.select_value(<<-SQL)
      SELECT col_description(
        (SELECT oid FROM pg_class WHERE relname = '#{table_name}'),
        (SELECT attnum FROM pg_attribute WHERE attname = '#{column_name}' AND attrelid = (SELECT oid FROM pg_class WHERE relname = '#{table_name}'))
      )
    SQL

    new_comment = if existing_comment.present?
                    "#{existing_comment} | #{comment}"
                  else
                    comment
                  end
    execute <<-SQL
      COMMENT ON COLUMN #{table_name}.#{column_name} IS '#{new_comment}'
    SQL
  end


end
