class TagComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render TagComponent.new.with_content('Base')
  end

  def big
    render TagComponent.new(big: true).with_content('Base')
  end

  def informative
    render TagComponent.new(informative: true).with_content('Informative')
  end

  def big_and_informative
    render TagComponent.new(big: true, informative: true).with_content('Informative')
  end
  # @!endgroup

  # @param big toggle
  # @param informative toggle
  # @param text text
  def workbench(big: false, informative: false, text: 'Base')
    render TagComponent.new(big:, informative:).with_content(text)
  end
end
