require 'rails_helper'
require 'data_uri'

RSpec.describe 'shared/_personal_key.html.erb' do
  let(:personal_key) { RandomPhrase.new(num_words: 4).to_s }

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
      render 'shared/personal_key', code: personal_key, update_path: '/test'

      doc = Nokogiri::HTML(rendered)
      download_link = doc.at_css('a[download]')
      data_uri = URI::Data.new(download_link[:href])

      expect(data_uri.content_type).to eq('text/plain')
      expect(data_uri.data).to eq(personal_key)
    end
  end
end
