# frozen_string_literal: true

class FormLinkComponent < BaseComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options
  end
end
