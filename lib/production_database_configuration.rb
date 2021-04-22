class ProductionDatabaseConfiguration
  READONLY_WARNING_MESSAGE = '
    WARNING: Loading database a configuration with the readonly database user.
    If you wish to make changes to records in the database set
    ALLOW_CONSOLE_DB_WRITE_ACCESS to "true" in the environment
  '.freeze.gsub(/^\s+/, '')

  def self.host
    if readonly_mode?
      raise if IdentityConfig.store.database_read_replica_host.blank?
      IdentityConfig.store.database_read_replica_host
    else
      IdentityConfig.store.database_host
    end
  end

  def self.username
    if readonly_mode?
      raise if IdentityConfig.store.database_readonly_username.blank?
      IdentityConfig.store.database_readonly_username
    else
      IdentityConfig.store.database_username
    end
  end

  def self.password
    if readonly_mode?
      raise if IdentityConfig.store.database_readonly_password.blank?
      IdentityConfig.store.database_readonly_password
    else
      IdentityConfig.store.database_password
    end
  end

  def self.pool
    IdentityConfig.store.database_pool_idp
  end

  private_class_method def self.readonly_mode?
    return false unless defined?(Rails::Console)
    return false unless readonly_credentials_present?
    return false if ENV['ALLOW_CONSOLE_DB_WRITE_ACCESS'] == 'true'
    print_readonly_warning
    true
  end

  private_class_method def self.readonly_credentials_present?
    IdentityConfig.store.database_readonly_username.present? &&
    IdentityConfig.store.database_readonly_password.present?
  end

  private_class_method def self.print_readonly_warning
    return if @readonly_warning.present?
    warn @readonly_warning ||= READONLY_WARNING_MESSAGE
  end
end
