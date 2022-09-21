require 'rails_helper'
require 'data_uri'

RSpec.describe 'shared/_personal_key.html.erb' do
  let(:personal_key) { RandomPhrase.new(num_words: 4).to_s }

  subject(:rendered) { render 'shared/personal_key', code: personal_key, update_path: '/test' }

  describe 'download link' do
    around do |ex|
      # data_uri depends on URI.decode which was removed in Ruby 3.0 :sob:
      module URI
        def self.decode(value)
          CGI.unescape(value)
        end
      end

      ex.run

      URI.singleton_class.undef_method(:decode)
    end

    it 'has the download attribute and a data: url for the personal key' do
      doc = Nokogiri::HTML(rendered)
      download_link = doc.at_css('a[download]')
      data_uri = URI::Data.new(download_link[:href])

      expect(data_uri.content_type).to eq('text/plain')
      expect(data_uri.data).to eq(personal_key)
    end
  end

  describe 'continue button' do
    let(:idv_personal_key_confirmation_enabled) { nil }

    before do
      allow(FeatureManagement).to receive(:idv_personal_key_confirmation_enabled?).
        and_return(idv_personal_key_confirmation_enabled)
    end

    context 'without idv personal key confirmation' do
      let(:idv_personal_key_confirmation_enabled) { false }

      it 'renders button with [data-toggle="skip"]' do
        expect(rendered).to have_css('[data-toggle="skip"]')
      end
    end

    context 'with idv personal key confirmation' do
      let(:idv_personal_key_confirmation_enabled) { true }

      it 'renders button with [data-toggle="modal"]' do
        expect(rendered).to have_css('[data-toggle="modal"]')
      end
    end
  end
end
