require 'rails_helper'

describe 'partials/personal_key/_key.html.erb' do
  let(:code) { 'abcd-efgh-ijkl-mnop' }

  it 'renders the code without whitespace between segments' do
    render 'partials/personal_key/key', code: code, show_save_buttons: true

    doc = Nokogiri::HTML(rendered)
    expect(doc.text).to include('abcdefghijklmnop')
  end
end
