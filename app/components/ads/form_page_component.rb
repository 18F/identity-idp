# frozen_string_literal: true

module ADS
  class FormPageComponent < BaseComponent
    renders_one :alert
    renders_one :media
    renders_one :body
    renders_one :actions

    attr_reader :title, :subtitle, :alert_position, :divider, :class_name, :html_options

    def initialize(
      title:,
      subtitle: nil,
      alert_position: :above,
      divider: false,
      class_name: nil,
      **html_options
    )
      @title = title
      @subtitle = subtitle
      @alert_position = alert_position.to_sym
      @divider = divider
      @class_name = class_name
      @html_options = html_options
    end

    def alert_below?
      alert_position == :below
    end

    def css_class
      ['ads-auth', 'ads-auth--form-page', class_name, html_options[:class]].compact
    end

    def flash_component
      @flash_component ||= FlashComponent.new(flash: helpers.flash)
    end

    def claim_flash!
      return false if helpers.content_for?(:form_page_flash)

      helpers.content_for(:form_page_flash, 'true')
      helpers.content_for(:skip_layout_flash, 'true')
      true
    end
  end
end
