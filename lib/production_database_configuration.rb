class ProductionDatabaseConfiguration
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
end
