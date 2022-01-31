require 'rails_helper'

describe 'partials/personal_key/_key.html.erb' do
  let(:code) { 'abcd-efgh-ijkl-mnop' }

  it 'renders the code segments' do
    render 'partials/personal_key/key', code: code

    doc = Nokogiri::HTML(rendered)
    segments = doc.css('[data-personal-key]').map(&:text)
    expect(segments.join).to eq('abcdefghijklmnop')
  end
end
