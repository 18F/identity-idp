# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `strong_migrations` gem.
# Please instead update this file by running `bin/tapioca gem strong_migrations`.


class ActiveRecord::Migration
  include ::StrongMigrations::Migration
end

class ActiveRecord::Migrator
  include ::StrongMigrations::Migrator
end

class ActiveRecord::SchemaDumper
  include ::StrongMigrations::SchemaDumper
end

module ActiveRecord::Tasks::DatabaseTasks
  extend ::StrongMigrations::DatabaseTasks
end

# TODO better pattern
#
# source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#1
module StrongMigrations
  class << self
    # source://strong_migrations//lib/strong_migrations.rb#66
    def add_check(&block); end

    # Returns the value of attribute alphabetize_schema.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def alphabetize_schema; end

    # Sets the attribute alphabetize_schema
    #
    # @param value the value to set the attribute alphabetize_schema to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def alphabetize_schema=(_arg0); end

    # Returns the value of attribute auto_analyze.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def auto_analyze; end

    # Sets the attribute auto_analyze
    #
    # @param value the value to set the attribute auto_analyze to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def auto_analyze=(_arg0); end

    # Returns the value of attribute check_down.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def check_down; end

    # Sets the attribute check_down
    #
    # @param value the value to set the attribute check_down to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def check_down=(_arg0); end

    # @return [Boolean]
    #
    # source://strong_migrations//lib/strong_migrations.rb#78
    def check_enabled?(check, version: T.unsafe(nil)); end

    # Returns the value of attribute checks.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def checks; end

    # Sets the attribute checks
    #
    # @param value the value to set the attribute checks to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def checks=(_arg0); end

    # private
    #
    # @return [Boolean]
    #
    # source://strong_migrations//lib/strong_migrations.rb#45
    def developer_env?; end

    # source://strong_migrations//lib/strong_migrations.rb#74
    def disable_check(check); end

    # source://strong_migrations//lib/strong_migrations.rb#70
    def enable_check(check, start_after: T.unsafe(nil)); end

    # Returns the value of attribute enabled_checks.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def enabled_checks; end

    # Sets the attribute enabled_checks
    #
    # @param value the value to set the attribute enabled_checks to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def enabled_checks=(_arg0); end

    # private
    #
    # source://strong_migrations//lib/strong_migrations.rb#50
    def env; end

    # Returns the value of attribute error_messages.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def error_messages; end

    # Sets the attribute error_messages
    #
    # @param value the value to set the attribute error_messages to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def error_messages=(_arg0); end

    # Returns the value of attribute lock_timeout.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout; end

    # Sets the attribute lock_timeout
    #
    # @param value the value to set the attribute lock_timeout to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout=(_arg0); end

    # source://strong_migrations//lib/strong_migrations.rb#59
    def lock_timeout_limit; end

    # Sets the attribute lock_timeout_limit
    #
    # @param value the value to set the attribute lock_timeout_limit to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#33
    def lock_timeout_limit=(_arg0); end

    # Returns the value of attribute lock_timeout_retries.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout_retries; end

    # Sets the attribute lock_timeout_retries
    #
    # @param value the value to set the attribute lock_timeout_retries to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout_retries=(_arg0); end

    # Returns the value of attribute lock_timeout_retry_delay.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout_retry_delay; end

    # Sets the attribute lock_timeout_retry_delay
    #
    # @param value the value to set the attribute lock_timeout_retry_delay to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def lock_timeout_retry_delay=(_arg0); end

    # Returns the value of attribute safe_by_default.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def safe_by_default; end

    # Sets the attribute safe_by_default
    #
    # @param value the value to set the attribute safe_by_default to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def safe_by_default=(_arg0); end

    # Returns the value of attribute start_after.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def start_after; end

    # Sets the attribute start_after
    #
    # @param value the value to set the attribute start_after to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def start_after=(_arg0); end

    # Returns the value of attribute statement_timeout.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def statement_timeout; end

    # Sets the attribute statement_timeout
    #
    # @param value the value to set the attribute statement_timeout to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def statement_timeout=(_arg0); end

    # Returns the value of attribute target_mariadb_version.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_mariadb_version; end

    # Sets the attribute target_mariadb_version
    #
    # @param value the value to set the attribute target_mariadb_version to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_mariadb_version=(_arg0); end

    # Returns the value of attribute target_mysql_version.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_mysql_version; end

    # Sets the attribute target_mysql_version
    #
    # @param value the value to set the attribute target_mysql_version to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_mysql_version=(_arg0); end

    # Returns the value of attribute target_postgresql_version.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_postgresql_version; end

    # Sets the attribute target_postgresql_version
    #
    # @param value the value to set the attribute target_postgresql_version to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_postgresql_version=(_arg0); end

    # Returns the value of attribute target_sql_mode.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_sql_mode; end

    # Sets the attribute target_sql_mode
    #
    # @param value the value to set the attribute target_sql_mode to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_sql_mode=(_arg0); end

    # Returns the value of attribute target_version.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_version; end

    # Sets the attribute target_version
    #
    # @param value the value to set the attribute target_version to.
    #
    # source://strong_migrations//lib/strong_migrations.rb#28
    def target_version=(_arg0); end
  end
end

# source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#2
module StrongMigrations::Adapters; end

# source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#3
class StrongMigrations::Adapters::AbstractAdapter
  # @return [AbstractAdapter] a new instance of AbstractAdapter
  #
  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#4
  def initialize(checker); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#27
  def add_column_default_safe?; end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#39
  def auto_incrementing_types; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#31
  def change_type_safe?(table, column, type, options, existing_column, existing_type); end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#23
  def check_lock_timeout(limit); end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#12
  def min_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#8
  def name; end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#35
  def rewrite_blocks; end

  # @raise [StrongMigrations::Error]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#19
  def set_lock_timeout(timeout); end

  # @raise [StrongMigrations::Error]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#15
  def set_statement_timeout(timeout); end

  private

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#45
  def connection; end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#49
  def select_all(statement); end

  # source://strong_migrations//lib/strong_migrations/adapters/abstract_adapter.rb#53
  def target_version(target_version); end
end

# source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#3
class StrongMigrations::Adapters::MariaDBAdapter < ::StrongMigrations::Adapters::MySQLAdapter
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#27
  def add_column_default_safe?; end

  # source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#8
  def min_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#4
  def name; end

  # source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#12
  def server_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/mariadb_adapter.rb#20
  def set_statement_timeout(timeout); end
end

# source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#5
class StrongMigrations::Adapters::MySQLAdapter < ::StrongMigrations::Adapters::AbstractAdapter
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#46
  def add_column_default_safe?; end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#42
  def analyze_table(table); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#50
  def change_type_safe?(table, column, type, options, existing_column, existing_type); end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#34
  def check_lock_timeout(limit); end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#10
  def min_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#6
  def name; end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#91
  def rewrite_blocks; end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#14
  def server_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#27
  def set_lock_timeout(timeout); end

  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#22
  def set_statement_timeout(timeout); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#86
  def strict_mode?; end

  private

  # do not memoize
  # want latest value
  #
  # source://strong_migrations//lib/strong_migrations/adapters/mysql_adapter.rb#99
  def sql_modes; end
end

# source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#3
class StrongMigrations::Adapters::PostgreSQLAdapter < ::StrongMigrations::Adapters::AbstractAdapter
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#44
  def add_column_default_safe?; end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#40
  def analyze_table(table); end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#172
  def auto_incrementing_types; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#48
  def change_type_safe?(table, column, type, options, existing_column, existing_type); end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#30
  def check_lock_timeout(limit); end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#130
  def constraints(table_name); end

  # default to true if unsure
  #
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#166
  def default_volatile?(default); end

  # only check in non-developer environments (where actual server version is used)
  #
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#159
  def index_corruption?; end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#8
  def min_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#4
  def name; end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#12
  def server_version; end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#26
  def set_lock_timeout(timeout); end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#22
  def set_statement_timeout(timeout); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#145
  def writes_blocked?; end

  private

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#212
  def datetime_type; end

  # columns is array for column index and string for expression index
  # the current approach can yield false positives for expression indexes
  # but prefer to keep it simple for now
  #
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#208
  def indexed?(table, column); end

  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#178
  def set_timeout(setting, timeout); end

  # do not memoize
  # want latest value
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#229
  def time_zone; end

  # units: https://www.postgresql.org/docs/current/config-setting.html
  #
  # source://strong_migrations//lib/strong_migrations/adapters/postgresql_adapter.rb#186
  def timeout_to_sec(timeout); end
end

# source://strong_migrations//lib/strong_migrations/checker.rb#2
class StrongMigrations::Checker
  include ::StrongMigrations::Checks
  include ::StrongMigrations::SafeMethods

  # @return [Checker] a new instance of Checker
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#12
  def initialize(migration); end

  # Returns the value of attribute direction.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def direction; end

  # Sets the attribute direction
  #
  # @param value the value to set the attribute direction to.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def direction=(_arg0); end

  # source://strong_migrations//lib/strong_migrations/checker.rb#30
  def perform(method, *args); end

  # source://strong_migrations//lib/strong_migrations/checker.rb#112
  def retry_lock_timeouts(check_committed: T.unsafe(nil)); end

  # Returns the value of attribute timeouts_set.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def timeouts_set; end

  # Sets the attribute timeouts_set
  #
  # @param value the value to set the attribute timeouts_set to.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def timeouts_set=(_arg0); end

  # Returns the value of attribute transaction_disabled.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def transaction_disabled; end

  # Sets the attribute transaction_disabled
  #
  # @param value the value to set the attribute transaction_disabled to.
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#6
  def transaction_disabled=(_arg0); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#128
  def version_safe?; end

  private

  # source://strong_migrations//lib/strong_migrations/checker.rb#179
  def adapter; end

  # source://strong_migrations//lib/strong_migrations/checker.rb#161
  def check_lock_timeout; end

  # source://strong_migrations//lib/strong_migrations/checker.rb#134
  def check_version_supported; end

  # source://strong_migrations//lib/strong_migrations/checker.rb#199
  def connection; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#203
  def retry_lock_timeouts?(method); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checker.rb#171
  def safe?; end

  # source://strong_migrations//lib/strong_migrations/checker.rb#148
  def set_timeouts; end

  # source://strong_migrations//lib/strong_migrations/checker.rb#175
  def version; end

  class << self
    # Returns the value of attribute safe.
    #
    # source://strong_migrations//lib/strong_migrations/checker.rb#9
    def safe; end

    # Sets the attribute safe
    #
    # @param value the value to set the attribute safe to.
    #
    # source://strong_migrations//lib/strong_migrations/checker.rb#9
    def safe=(_arg0); end

    # source://strong_migrations//lib/strong_migrations/checker.rb#20
    def safety_assured; end
  end
end

# source://strong_migrations//lib/strong_migrations/checks.rb#3
module StrongMigrations::Checks
  private

  # source://strong_migrations//lib/strong_migrations/checks.rb#384
  def ar_version; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#435
  def backfill_code(table, column, default, function = T.unsafe(nil)); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#6
  def check_add_check_constraint(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#30
  def check_add_column(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#81
  def check_add_exclusion_constraint(*args); end

  # unlike add_index, we don't make an exception here for new tables
  #
  # with add_index, it's fine to lock a new table even after inserting data
  # since the table won't be in use by the application
  #
  # with add_foreign_key, this would cause issues since it locks the referenced table
  #
  # it's okay to allow if the table is empty, but not a fan of data-dependent checks,
  # since the data in production could be different from development
  #
  # note: adding foreign_keys with create_table is fine
  # since the table is always guaranteed to be empty
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#101
  def check_add_foreign_key(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#118
  def check_add_index(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#143
  def check_add_reference(method, *args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#179
  def check_add_unique_constraint(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#194
  def check_change_column(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#215
  def check_change_column_default(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#227
  def check_change_column_null(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#275
  def check_change_table; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#279
  def check_create_join_table(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#287
  def check_create_table(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#297
  def check_execute; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#301
  def check_remove_column(method, *args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#333
  def check_remove_index(*args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#350
  def check_rename_column; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#354
  def check_rename_table; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#358
  def check_validate_check_constraint; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#364
  def check_validate_foreign_key; end

  # source://strong_migrations//lib/strong_migrations/checks.rb#412
  def command_str(command, args); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#403
  def constraint_str(statement, identifiers); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#380
  def mariadb?; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#376
  def mysql?; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#456
  def new_column?(table, column); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#452
  def new_table?(table); end

  # helpers
  #
  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#372
  def postgresql?; end

  # only quote when needed
  # important! only use for display purposes
  #
  # source://strong_migrations//lib/strong_migrations/checks.rb#448
  def quote_column_if_needed(column); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#388
  def raise_error(message_key, header: T.unsafe(nil), append: T.unsafe(nil), **vars); end

  # source://strong_migrations//lib/strong_migrations/checks.rb#408
  def safety_assured_str(code); end
end

# source://strong_migrations//lib/strong_migrations/database_tasks.rb#2
module StrongMigrations::DatabaseTasks
  # Active Record 7 adds version argument
  #
  # source://strong_migrations//lib/strong_migrations/database_tasks.rb#4
  def migrate(*args); end
end

# source://strong_migrations//lib/strong_migrations.rb#23
class StrongMigrations::Error < ::StandardError; end

# source://strong_migrations//lib/strong_migrations/migration.rb#2
module StrongMigrations::Migration
  # source://strong_migrations//lib/strong_migrations/migration.rb#9
  def method_missing(method, *args, **_arg2); end

  # source://strong_migrations//lib/strong_migrations/migration.rb#3
  def migrate(direction); end

  # source://strong_migrations//lib/strong_migrations/migration.rb#23
  def revert(*_arg0); end

  # source://strong_migrations//lib/strong_migrations/migration.rb#31
  def safety_assured; end

  # @raise [StrongMigrations::UnsafeMigration]
  #
  # source://strong_migrations//lib/strong_migrations/migration.rb#37
  def stop!(message, header: T.unsafe(nil)); end

  private

  # source://strong_migrations//lib/strong_migrations/migration.rb#43
  def strong_migrations_checker; end
end

# source://strong_migrations//lib/strong_migrations/migrator.rb#2
module StrongMigrations::Migrator
  # source://strong_migrations//lib/strong_migrations/migrator.rb#3
  def ddl_transaction(migration, *args); end
end

# source://strong_migrations//lib/strong_migrations/railtie.rb#5
class StrongMigrations::Railtie < ::Rails::Railtie; end

# source://strong_migrations//lib/strong_migrations/safe_methods.rb#2
module StrongMigrations::SafeMethods
  # hard to commit at right time when reverting
  # so just commit at start
  #
  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#110
  def disable_transaction; end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#117
  def in_transaction?; end

  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#62
  def safe_add_check_constraint(table, expression, *args, add_options, validate_options); end

  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#47
  def safe_add_foreign_key(from_table, to_table, *args, **options); end

  # TODO check if invalid index with expected name exists and remove if needed
  #
  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#8
  def safe_add_index(*args, **options); end

  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#18
  def safe_add_reference(table, reference, *args, **options); end

  # @return [Boolean]
  #
  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#3
  def safe_by_default_method?(method); end

  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#75
  def safe_change_column_null(add_code, validate_code, change_args, remove_code, default); end

  # source://strong_migrations//lib/strong_migrations/safe_methods.rb#13
  def safe_remove_index(*args, **options); end
end

# source://strong_migrations//lib/strong_migrations/schema_dumper.rb#2
module StrongMigrations::SchemaDumper
  # source://strong_migrations//lib/strong_migrations/schema_dumper.rb#3
  def initialize(connection, *args, **options); end
end

# source://strong_migrations//lib/strong_migrations.rb#24
class StrongMigrations::UnsafeMigration < ::StrongMigrations::Error; end

# source://strong_migrations//lib/strong_migrations.rb#25
class StrongMigrations::UnsupportedVersion < ::StrongMigrations::Error; end

# source://strong_migrations//lib/strong_migrations/version.rb#2
StrongMigrations::VERSION = T.let(T.unsafe(nil), String)

# source://strong_migrations//lib/strong_migrations/schema_dumper.rb#10
class StrongMigrations::WrappedConnection
  # @return [WrappedConnection] a new instance of WrappedConnection
  #
  # source://strong_migrations//lib/strong_migrations/schema_dumper.rb#13
  def initialize(connection); end

  # source://strong_migrations//lib/strong_migrations/schema_dumper.rb#17
  def columns(*args, **options); end

  # source://activesupport/7.2.1.1/lib/active_support/delegation.rb#187
  def method_missing(method, *_arg1, **_arg2, &_arg3); end

  private

  # source://activesupport/7.2.1.1/lib/active_support/delegation.rb#179
  def respond_to_missing?(name, include_private = T.unsafe(nil)); end
end
