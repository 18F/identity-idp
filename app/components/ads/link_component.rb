# frozen_string_literal: true

module ADS
  class LinkComponent < BaseComponent
    attr_reader :url, :html_options

    def initialize(url:, **html_options)
      @url = url
      @html_options = html_options
    end

    def call
      link_to(url, **html_options.except(:class), class: css_class) { content }
    end

    private

    def css_class
      helpers.class_names('ads-link', html_options[:class])
    end
  end
end
