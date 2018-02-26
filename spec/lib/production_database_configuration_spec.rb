require 'rails_helper'

describe ProductionDatabaseConfiguration do
  describe '.pool' do
    context 'when the app is running on an idp host' do
      before { stub_role_config('idp') }

      it 'returns the idp pool size' do
        allow(Figaro.env).to receive(:database_pool_idp).and_return(7)

        expect(ProductionDatabaseConfiguration.pool).to eq(7)
      end

      it 'defaults to 5' do
        allow(Figaro.env).to receive(:database_pool_idp).and_return(nil)

        expect(ProductionDatabaseConfiguration.pool).to eq(5)

        allow(Figaro.env).to receive(:database_pool_idp).and_return('')

        expect(ProductionDatabaseConfiguration.pool).to eq(5)
      end
    end

    context 'when the app is running on a worker host' do
      before { stub_role_config('worker') }

      it 'returns the worker pool size' do
        allow(Figaro.env).to receive(:database_pool_worker).and_return(8)

        expect(ProductionDatabaseConfiguration.pool).to eq(8)
      end

      it 'defaults to 26' do
        allow(Figaro.env).to receive(:database_pool_worker).and_return(nil)

        expect(ProductionDatabaseConfiguration.pool).to eq(26)

        allow(Figaro.env).to receive(:database_pool_worker).and_return('')

        expect(ProductionDatabaseConfiguration.pool).to eq(26)
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
        allow(File).to receive(:exist?).with('/etc/login.gov/info').and_return(false)
      end

      it 'returns 5 and does not read the role config' do
        expect(File).to_not receive(:read)
        expect(ProductionDatabaseConfiguration.pool).to eq(5)
      end
    end
  end

  def stub_role_config(role)
    allow(File).to receive(:exist?).with('/etc/login.gov/info').and_return(true)
    allow(File).to receive(:read).with('/etc/login.gov/info').and_return(role)
  end
end
