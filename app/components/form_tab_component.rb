# frozen_string_literal: true

class FormTabComponent < ViewComponent::Base
  renders_many :tabs, ->(label:, &content_block) do
    TabItem.new(label:, content_block:)
  end

  def initialize(form:)
    @form = form
  end

  class TabItem < ViewComponent::Base
    attr_reader :label

    def initialize(label:, content_block:)
      @label = label
      @content_block = content_block
    end

    def call
      @content_block.call
    end
  end
end
