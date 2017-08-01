require 'rails_helper'

RSpec.describe 'SVG files' do
  Dir[Rails.root.join('**', '*.svg')].reject { |f| f.include?('node_modules') }.each do |svg_path|
    relative_path = svg_path.sub(Rails.root.to_s, '')

    describe relative_path do
      it 'does not contain inline style tags (that render poorly in IE due to CSP)' do
        doc = Nokogiri::XML(File.read(svg_path))

        expect(doc.css('style')).to be_empty
      end
    end
  end
end
