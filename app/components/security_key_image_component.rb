# frozen_string_literal: true

class SecurityKeyImageComponent < BaseComponent
  def initialize(mobile:)
    @mobile = mobile
  end

  def mobile?
    !!@mobile
  end

  def call
    # rubocop:disable Rails/OutputSafety
    @svg_tag ||= Nokogiri::HTML5.fragment(read_svg).tap do |doc|
      doc.at_css('svg').tap do |svg|
        svg[:height] = 193
        svg[:width] = 420
        svg[:class] = css_class
        svg[:role] = 'img'

        svg << "<title>#{title}</title>"
      end
    end.to_s.html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def css_class
    [
      'height-auto',
      mobile? && 'security-key--mobile',
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
