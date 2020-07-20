module Features
  module StripTagsHelper
    def strip_tags(*args)
      ActionController::Base.helpers.strip_tags(*args)
    end

    def strip_nbsp(text)
      nbsp = Nokogiri::HTML.parse('&nbsp;').text
      text.gsub(/&nbsp;/, ' ').gsub(/#{nbsp}/, ' ')
    end
  end
end
