class ProductionDatabaseConfiguration
  READONLY_WARNING_MESSAGE = '
    WARNING: Loading database a configuration with the readonly database user.
    If you wish to make changes to records in the database set
    ALLOW_CONSOLE_DB_WRITE_ACCESS to "true" in the environment
  '.freeze.gsub(/^\s+/, '')

  def self.username
    env = Figaro.env
    return env.database_username! unless readonly_mode?
    env.database_readonly_username!
  end

  def self.password
    env = Figaro.env
    return env.database_password! unless readonly_mode?
    env.database_readonly_password!
  end

  def self.pool
    env = Figaro.env
    role = File.read('/etc/login.gov/info/role') if File.exist?('/etc/login.gov/info/role')
    case role
    when 'idp'
      env.database_pool_idp.presence || 5
    when 'worker'
      env.database_pool_worker.presence || 26
    else
      5
    end
  end

  private_class_method def self.readonly_mode?
    return false unless defined?(Rails::Console)
    return false unless readonly_credentials_present?
    return false if ENV['ALLOW_CONSOLE_DB_WRITE_ACCESS'] == 'true'
    print_readonly_warning
    true
  end

  private_class_method def self.readonly_credentials_present?
    env = Figaro.env
    env.database_readonly_username.present? &&
    env.database_readonly_password.present?
  end

  private_class_method def self.print_readonly_warning
    return if @readonly_warning.present?
    warn @readonly_warning ||= READONLY_WARNING_MESSAGE
  end
end
