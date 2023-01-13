require 'rails_helper'

RSpec.describe 'shared/_personal_key.html.erb' do
  let(:personal_key) { RandomPhrase.new(num_words: 4).to_s }

  subject(:rendered) { render 'shared/personal_key', code: personal_key, update_path: '/test' }

  describe 'download link' do
    it 'has the download attribute and a data: url for the personal key' do
      doc = Nokogiri::HTML(rendered)
      download_link = doc.at_css('a[download]')
      data_uri = Idv::DataUrlImage.new(download_link[:href])

      expect(data_uri.content_type).to include('text/plain')
      expect(data_uri.read).to eq(personal_key)
    end
  end
end
