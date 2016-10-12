require 'rails_helper'

describe 'i18n override' do
  describe '.translate_with_markup' do
    it 'provides anchor tag to translated source' do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(true)
      require File.join(Rails.root, 'lib', 'i18n_override.rb')

      localized_str = I18n.translate_with_markup('shared.usa_banner.official_site')

      expect(localized_str).to eq('An official website of the United States government' \
        '<small class="i18n-anchor"><a href="https://github.com/18F/identity-idp/' \
        'tree/master/config/locales/en.yml#L404" target="_blank" class="ml-tiny ' \
        'no-hover-decoration">🔗</a></small>')
    end
  end
end
