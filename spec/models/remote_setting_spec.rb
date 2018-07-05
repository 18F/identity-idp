require 'rails_helper'

describe RemoteSetting do
  describe 'validations' do
    it 'validates that our github repo is white listed' do
      location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
      valid_setting = RemoteSetting.create(name: 'agencies.yml', url: location, contents: '')
      expect(valid_setting).to be_valid
    end

    it 'validates that the login.gov static site is white listed' do
      location = 'https://login.gov/agencies.yml'
      valid_setting = RemoteSetting.create(name: 'agencies.yml', url: location, contents: '')
      expect(valid_setting).to be_valid
    end

    it 'does not accept http' do
      location = 'http://login.gov/agencies.yml'
      valid_setting = RemoteSetting.create(name: 'agencies.yml', url: location, contents: '')
      expect(valid_setting).to_not be_valid
    end
  end
end
