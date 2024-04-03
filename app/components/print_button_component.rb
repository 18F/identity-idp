# frozen_string_literal: true

class PrintButtonComponent < ButtonComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    super(**tag_options, type: :button, icon: :print)
  end

  def call
    content_tag(:'lg-print-button', super)
  end

  def content
    t('components.print_button.label')
  end
end
