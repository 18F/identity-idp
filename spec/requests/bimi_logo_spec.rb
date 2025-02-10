require 'rails_helper'

RSpec.describe 'BIMI logo' do
  let(:image_response) do
    get '/images/login-icon-bimi.svg'
    response
  end
  subject(:image) { Nokogiri::XML(image_response.body) }

  it 'is available' do
    # If you're troubleshooting this spec, there's a good chance you're trying to remove a file that
    # appears to be unused. This comment is here to assure you that it is in-fact used, referenced
    # as part of the BIMI DMARC records associated with the Login.gov domain. The image should not
    # be removed as long as it's referenced by those records.
    expect(image_response.status).to eq(200)
  end

  describe 'validity' do
    # Test cases in this block reference best practices documentation from BIMI group:
    # See: https://bimigroup.org/creating-bimi-svg-logo-files/

    it 'is no larger than 32kb' do
      # "The SVG document should be as small as possible and should not exceed 32 kilobytes."
      size_in_kilobytes = image_response.content_length.to_f / 1024

      expect(size_in_kilobytes).to be <= 32
    end

    it 'has expected root attributes' do
      # "When building your SVG there are a number of required elements in the structure of the
      # file:"

      # "The “baseProfile” attribute set to “tiny-ps”"
      expect(image.css('svg[baseProfile="tiny-ps"]')).to be_present

      # "The “version” attribute set to “1.2”"
      expect(image.css('svg[version="1.2"]')).to be_present

      # "A <title> element must be included that reflects the company name, though there are no
      # strict requirements for the content of the element."
      expect(image.css('title').text).to be_present
    end

    it 'does not include forbidden elements' do
      # "The SVG document must not include any of the following in order to be valid under the
      # tiny-ps designation:"

      # "Any external links or references (other than to the specified XML namespaces)"
      # expect(image.css('[xlink\\:href]')).to be_blank
      expect(image.xpath('//*[@href]')).to be_blank

      # "Any scripts, animation, or other interactive elements"
      expect(image.css('animate')).to be_blank
      expect(image.css('script')).to be_blank

      # "“x=” or “y=” attributes within the <svg> root element"
      expect(image.css('[x]')).to be_blank
      expect(image.css('[y]')).to be_blank
    end

    it 'is square' do
      # "The image should be a square aspect ratio"
      root = image.css('svg')
      width = root.attr('width').value
      height = root.attr('height').value

      expect(width).to eq(height)
    end
  end
end
