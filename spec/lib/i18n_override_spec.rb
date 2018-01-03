require 'rails_helper'

describe 'i18n override' do
  describe '.translate_with_markup' do
    it 'provides anchor tag to translated source' do
      allow(FeatureManagement).to receive(:enable_i18n_mode?).and_return(true)
      require Rails.root.join('lib', 'i18n_override.rb')

      localized_str = I18n.translate_with_markup('shared.usa_banner.official_site')

      regex = /^An official website of the United States government.+i18n-anchor/
      file_path = '/18F/identity-idp/blob/master/config/locales/shared/en.yml'

      expect(localized_str).to match regex
      expect(localized_str.scan(URI::DEFAULT_PARSER.make_regexp).flatten).to include(file_path)
    end
  end
end
