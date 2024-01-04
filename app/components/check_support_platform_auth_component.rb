class CheckSupportPlatformAuthComponent < BaseComponent
  attr_reader :tag_options

  def initialize(form:, name:, **tag_options)
    @tag_options = tag_options
  end

end