# frozen_string_literal: true

class LoginButtonComponent < BaseComponent
  VALID_COLORS = ['primary', 'primary-darker', 'primary-lighter'].freeze

  css_file_path = Rails.root.join(
    'app',
    'assets',
    'builds',
    'login_button_component.css',
  )

  CSS = File.read(css_file_path)

  attr_reader :color, :big, :css, :tag_options

  def initialize(color: 'primary', big: false, **tag_options)
    if !VALID_COLORS.include?(color)
      raise ArgumentError, "`color` #{color}} is invalid, expected one of #{VALID_COLORS}"
    end

    @css = CSS
    @big = big
    @color = color
    @tag_options = tag_options

  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << "login-button login-button--#{color}"
    classes
  end
end
