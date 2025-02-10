require 'rails_helper'

RSpec.describe 'SVG files' do
  files = Dir.glob('{app,public}/**/*.svg', base: Rails.root)
  files.reject! { |f| f.start_with? 'public/assets/' }
  files.each do |relative_path|
    describe relative_path do
      let(:subject) { Nokogiri::XML(File.read(Rails.root.join(relative_path))) }

      it 'does not contain inline style tags (which violate CSP)' do
        expect(subject.css('style')).to be_empty.or(
          have_attributes(text: match(%r{^\s*/\*!lint-ignore\*/})),
        )
      end

      it 'defines viewBox attribute' do
        expect(subject.css('[viewBox]')).to be_present
      end
    end
  end
end
