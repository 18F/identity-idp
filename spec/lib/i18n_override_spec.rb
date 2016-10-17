require 'rails_helper'

describe 'i18n override' do
  describe '.translate_with_markup' do
    it 'provides anchor tag to translated source' do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(true)
      require File.join(Rails.root, 'lib', 'i18n_override.rb')

      localized_str = I18n.translate_with_markup('shared.usa_banner.official_site')

      regex = /^An official website of the United States government.+i18n-anchor/

      expect(localized_str).to match regex
    end
  end
end
