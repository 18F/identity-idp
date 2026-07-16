require 'rails_helper'

RSpec.describe NavigationPresenter do
  include Rails.application.routes.url_helpers

  subject(:navigation) { NavigationPresenter.new(url_options: {}) }

  describe '#navigation_items' do
    it 'returns the four flat dashboard navigation items' do
      items = navigation.navigation_items

      expect(items.map(&:title)).to eq(
        [
          t('account.navigation.home'),
          t('account.navigation.profile'),
          t('account.navigation.security'),
          t('account.navigation.history'),
        ],
      )
      expect(items.map(&:href)).to eq(
        [
          account_path,
          account_settings_path,
          account_security_path,
          account_history_path,
        ],
      )
      expect(items.map(&:icon)).to eq(%i[house profile_circle lock clock])
    end
  end
end
