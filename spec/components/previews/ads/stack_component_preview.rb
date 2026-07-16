class ADS::StackComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param kind select [stack,flow,form,actions,links]
  # @param gap select [~,8,12,16,24,32]
  # @param align select [~,center,start,stretch]
  def workbench(kind: :stack, gap: 16, align: :stretch)
    render(ADS::StackComponent.new(kind: kind.to_sym, gap: gap, align: align)) do
      safe_join(
        [
          tag.div('First item', style: 'padding: 12px; background: #f0f0f0;'),
          tag.div('Second item', style: 'padding: 12px; background: #e8e8e8;'),
          tag.div('Third item', style: 'padding: 12px; background: #f0f0f0;'),
        ],
      )
    end
  end
end
