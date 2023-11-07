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

  describe '#with_user_locale' do
    let(:user) { build_stubbed(:user, email_language:) }

    subject do
      with_user_locale(user) do
        @locale_inside_block = I18n.locale
        @did_yield = true
      end
    end

    context 'when the user has no email_language' do
      let(:email_language) { '' }

      it 'yields the block and does not change the locale' do
        subject

        expect(@locale_inside_block).to eq(:en)
        expect(@did_yield).to eq(true)
      end
    end

    context 'when the user has an email_language' do
      let(:email_language) { 'es' }

      it 'sets the language inside the block and yields' do
        subject

        expect(@locale_inside_block).to eq(:es)
        expect(@did_yield).to eq(true)
      end
    end

    context 'when the user has an invalid email_language' do
      let(:email_language) { 'zz' }

      it 'yields the block and does not change the locale' do
        subject

        expect(@locale_inside_block).to eq(:en)
        expect(@did_yield).to eq(true)
      end

      it 'warns about a bad email_language' do
        expect(Rails.logger).to receive(:warn).
          with("user_id=#{user.uuid} has bad email_language=#{user.email_language}")

        subject
      end
    end
  end
end
