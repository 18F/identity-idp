require 'rails_helper'

describe Link do
  describe '#to_s' do
    it 'returns the url based on the path name, link text, and params' do
      path_name = 'root'
      link_text = 'hello world'
      params = { cat: 'dog' }

      url = Link.new(path_name: path_name, link_text: link_text, params: params).to_s

      expect(url).to eq('<a href="/?cat=dog">hello world</a>')
    end
  end
end
