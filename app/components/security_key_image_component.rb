# frozen_string_literal: true

class SecurityKeyImageComponent < BaseComponent
  attr_reader :tag_options

  def initialize(mobile:, **tag_options)
    @mobile = mobile
    @tag_options = tag_options
  end

  def mobile?
    !!@mobile
  end

  def call
    # rubocop:disable Rails/OutputSafety
    Nokogiri::HTML5.fragment(read_svg).tap do |doc|
      doc.at_css('svg').tap do |svg|
        svg[:class] = css_class
        svg[:role] = 'img'

        tag_options.except(:class, :data, :aria).each do |key, value|
          svg[key] = value
        end
        [:data, :aria].each do |prefix|
          tag_options[prefix]&.each do |key, value|
            svg[:"#{prefix}-#{key}"] = value
          end
        end

        svg << "<title>#{title}</title>"
      end
    end.to_s.html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def css_class
    [
      'width-full',
      'height-auto',
      mobile? && 'security-key--mobile',
      *tag_options[:class],
    ].select(&:present?).join(' ')
  end

  def title
    mobile? ?
      t('forms.webauthn_setup.step_2_image_mobile_alt') :
      t('forms.webauthn_setup.step_2_image_alt')
  end

  def read_svg
    Rails.root.join(
      'app', 'assets', 'images', 'mfa-options',
      (mobile? ? 'security_key_mobile.svg' : 'security_key.svg')
    ).read
  end
end
