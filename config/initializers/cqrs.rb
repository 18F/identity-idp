require_relative '../../db/cqrs_migrations'

Rails.application.reloader.to_prepare do
  Sequent.configure do |config|
    config.migrations_class_name = 'SequentMigrations'

    config.command_handlers = [
      # add you Sequent::CommandHandler's here
    ]

    config.event_handlers = [
      # add you Sequent::Projector's or Sequent::Workflow's here
    ]

    config.database_config_directory = 'config'

    # this is the location of your sql files for your view_schema
    config.migration_sql_files_directory = 'db/cqrs'

    # we use multiple databases, see:
    # https://github.com/zilverline/sequent/blob/master/lib/sequent/configuration.rb#L63
    config.enable_multiple_database_support = true
  end
end
