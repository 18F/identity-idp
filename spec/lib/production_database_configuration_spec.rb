require 'rails_helper'

describe ProductionDatabaseConfiguration do
  let(:database_username) { 'db_user' }
  let(:database_password) { 'db_pass' }
  let(:database_readonly_username) { 'db_readonly_user' }
  let(:database_readonly_password) { 'db_readonly_pass' }
  let(:database_read_replica_host) { 'read_only_host' }
  let(:database_host) { 'read_write_host' }

  before do
    allow(IdentityConfig.store).to receive(:database_username).and_return(database_username)
    allow(IdentityConfig.store).to receive(:database_password).and_return(database_password)
    allow(IdentityConfig.store).to receive(:database_readonly_username).and_return(
      database_readonly_username,
    )
    allow(IdentityConfig.store).to receive(:database_readonly_password).and_return(
      database_readonly_password,
    )
    allow(ProductionDatabaseConfiguration).to receive(:warn)
    allow(IdentityConfig.store).to receive(:database_read_replica_host).and_return(
      database_read_replica_host,
    )
    allow(IdentityConfig.store).to receive(:database_host).and_return(database_host)
  end

  describe '.username' do
    context 'when app is running in a console' do
      before { stub_rails_console }

      it 'returns the readonly username' do
        expect(ProductionDatabaseConfiguration.username).to eq(database_readonly_username)
      end
    end

    context 'when the app is running in a console without readonly user credentials' do
      it 'returns the read/write username' do
        allow(IdentityConfig.store).to receive(:database_readonly_username).and_return('')
        allow(IdentityConfig.store).to receive(:database_readonly_password).and_return('')

        expect(ProductionDatabaseConfiguration.username).to eq(database_username)
      end
    end

    context 'when the app is running in a console with the write access flag' do
      before do
        stub_rails_console
        stub_environment_write_access_flag
      end

      it 'returns the read/write username' do
        expect(ProductionDatabaseConfiguration.username).to eq(database_username)
      end
    end

    context 'when the app is not running in a console' do
      it 'returns the read/write username' do
        expect(ProductionDatabaseConfiguration.username).to eq(database_username)
      end
    end
  end

  describe '.host' do
    context 'when app is running in a console' do
      before { stub_rails_console }

      it 'returns the readonly host' do
        expect(ProductionDatabaseConfiguration.host).to eq(database_read_replica_host)
      end
    end

    context 'when the app is running in a console without readonly user credentials' do
      it 'returns the read/write host' do
        allow(IdentityConfig.store).to receive(:database_readonly_username).and_return('')
        allow(IdentityConfig.store).to receive(:database_readonly_password).and_return('')

        expect(ProductionDatabaseConfiguration.host).to eq(database_host)
      end
    end

    context 'when the app is running in a console with the write access flag' do
      before do
        stub_rails_console
        stub_environment_write_access_flag
      end

      it 'returns the read/write host' do
        expect(ProductionDatabaseConfiguration.host).to eq(database_host)
      end
    end

    context 'when the app is not running in a console' do
      it 'returns the read/write host' do
        expect(ProductionDatabaseConfiguration.host).to eq(database_host)
      end
    end
  end

  describe '.password' do
    context 'when app is running in a console' do
      before { stub_rails_console }

      it 'returns the readonly password' do
        expect(ProductionDatabaseConfiguration.password).to eq(database_readonly_password)
      end
    end

    context 'when the app is running in a console without readonly user credentials' do
      it 'returns the read/write username' do
        allow(IdentityConfig.store).to receive(:database_readonly_username).and_return('')
        allow(IdentityConfig.store).to receive(:database_readonly_password).and_return('')

        expect(ProductionDatabaseConfiguration.password).to eq(database_password)
      end
    end

    context 'when the app is running in a console with the write access flag' do
      before do
        stub_rails_console
        stub_environment_write_access_flag
      end

      it 'returns the read/write password' do
        expect(ProductionDatabaseConfiguration.password).to eq(database_password)
      end
    end

    context 'when the app is not running in a console' do
      it 'returns the read/write password' do
        expect(ProductionDatabaseConfiguration.password).to eq(database_password)
      end
    end
  end

  describe '.pool' do
    context 'when the app is running on an idp host' do
      before { stub_role_config('idp') }

      it 'returns the idp pool size' do
        allow(IdentityConfig.store).to receive(:database_pool_idp).and_return(7)

        expect(ProductionDatabaseConfiguration.pool).to eq(7)
      end
    end

    context 'when the app is running on an host with an ambigous role' do
      before { stub_role_config('fake') }

      it 'returns a default of 5' do
        expect(ProductionDatabaseConfiguration.pool).to eq(5)
      end
    end

    context 'when the app is running on a host without a role config file' do
      before do
        allow(File).to receive(:exist?).with('/etc/login.gov/info/role').and_return(false)
      end

      it 'returns 5 and does not read the role config' do
        expect(File).to_not receive(:read)
        expect(ProductionDatabaseConfiguration.pool).to eq(5)
      end
    end
  end

  def stub_rails_console
    stub_const('Rails::Console', Object)
  end

  def stub_environment_write_access_flag
    allow(ENV).to receive(:[]).with('ALLOW_CONSOLE_DB_WRITE_ACCESS').and_return('true')
  end

  def stub_role_config(role)
    allow(File).to receive(:exist?).with('/etc/login.gov/info/role').and_return(true)
    allow(File).to receive(:read).with('/etc/login.gov/info/role').and_return(role)
  end
end
