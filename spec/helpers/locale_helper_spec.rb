require 'rails_helper'

RSpec.describe LocaleHelper do
  include LocaleHelper

  describe '#locale_url_param' do
    context 'in the default locale' do
      before { I18n.locale = :en }

      it 'is nil' do
        expect(locale_url_param).to be_nil
      end
    end

    context 'in French (a non-default locale)' do
      before { I18n.locale = :fr }

      it 'is that locale' do
        expect(locale_url_param).to eq(:fr)
      end
    end

    context 'in Spanish (a non-default locale)' do
      before { I18n.locale = :es }

      it 'is that locale' do
        expect(locale_url_param).to eq(:es)
      end
    end
  end
end
