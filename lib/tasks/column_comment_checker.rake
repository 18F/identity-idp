# frozen_string_literal: true

namespace :db do
  desc 'Check for columns with sensitivity comments'
  task check_for_sensitive_columns: :environment do
    puts 'Checking for columns with sensitivity comments...'
    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]
    missing_columns = []

    tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        next if column.name == 'id'

        if !column.comment&.match?(/sensitive=(true|false)/i)
          missing_columns << "#{table}##{column.name}"
        end
      end
    end

    if missing_columns.any?
      puts 'Columns with sensitivity comments found:'
      missing_columns.each { |column| puts column }
      puts <<-INFO
        In your migration, add 'comment: sensitive=false'(or true for sensitive data)
        to all of the listed columns."
      INFO
    else
      puts 'All columns have sensitivity comments.'
    end
  end
end
