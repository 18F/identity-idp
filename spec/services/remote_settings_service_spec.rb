require 'rails_helper'

describe RemoteSettingsService do
  subject(:service) { RemoteSettingsService }

  describe '.load_yml_erb' do
    it 'loads the remote location' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
      stub_request(:get, location).to_return(body: Rails.root.join('config', 'agencies.yml').read)

      expect { service.load_yml_erb(location) }.to_not raise_error
    end

    it 'raises an error if the location is not https://' do
      location = 'agencies.yml'
      expect do
        RemoteSettingsService.load_yml_erb(location)
      end.to raise_error(RuntimeError, "Location must begin with 'https://': #{location}")
    end

    it 'raises an error if the file is not found' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies'
      stub_request(:get, location).to_return(status: 404)

      expect do
        service.load_yml_erb(location)
      end.to raise_error(RuntimeError, "Error retrieving: #{location}")
    end

    it 'raises an error if the file is not a yml file' do
      location = 'https://github.com/18F/identity-idp/blob/master/public/images/logo.svg'
      stub_request(:get, location).to_return(body: '%')

      expect do
        service.load_yml_erb(location)
      end.to raise_error(RuntimeError, "Error parsing yml file: #{location}")
    end
  end

  describe '.load' do
    it 'loads the remote location' do
      location = 'https://github.com/18F/identity-idp/blob/master/public/images/logo.svg'
      stub_request(:get, location).to_return(body: '<?xml version="1.0"?><svg></svg>')

      expect do
        service.load(location)
      end.to_not raise_error
    end

    it 'raises an error if the location is not https://' do
      location = 'agencies.yml'
      expect do
        RemoteSettingsService.load(location)
      end.to raise_error(RuntimeError, "Location must begin with 'https://': #{location}")
    end

    it 'raises an error if the file is not found' do
      location = 'https://github.com/18F/identity-idp/blob/master/public/images/logo'
      stub_request(:get, location).to_return(status: 404)
      expect do
        service.load(location)
      end.to raise_error(RuntimeError, "Error retrieving: #{location}")
    end
  end

  describe '.update_setting' do
    it 'it creates a setting if it does not exist' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
      stub_request(:get, location).
        to_return(body: Rails.root.join('config', 'agencies.localdev.yml'))

      service.update_setting('agencies.yml', location)
      expect(RemoteSetting.find_by(name: 'agencies.yml').url).to eq(location)
    end

    it 'it updates the setting if it exists' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
      stub_request(:get, location).
        to_return(body: Rails.root.join('config', 'agencies.localdev.yml'))

      agencies = 'agencies.yml'
      service.update_setting(agencies, location)
      service.update_setting(agencies, location)
      expect(RemoteSetting.find_by(name: agencies).url).to eq(location)
    end
  end

  describe '.remote?' do
    it 'returns true if it is a remote location' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
      expect(subject.remote?(location)).to eq(true)
    end

    it 'returns false if it is not a remote location' do
      location = 'agencies.yml'
      expect(subject.remote?(location)).to eq(false)
    end
  end
end
