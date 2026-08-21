module NDS
  # Net-new NDS layout primitive; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  class StackComponentPreview < BaseComponentPreview
    include ActionView::Helpers::TagHelper

    def default
      render(NDS::StackComponent.new(gap: 12)) do
        safe_join(
          ['One', 'Two', 'Three'].map { |label| content_tag(:div, label) },
        )
      end
    end

    def form_group
      render(NDS::StackComponent.new(kind: :form)) do
        safe_join(
          ['Name', 'Email', 'Password'].map { |label| content_tag(:div, label) },
        )
      end
    end

    def actions
      render(NDS::StackComponent.new(kind: :actions, gap: 12)) do
        safe_join(
          [
            content_tag(:button, 'Continue', type: 'button', class: 'usa-button'),
            content_tag(
              :button, 'Cancel',
              type: 'button', class: 'usa-button usa-button--outline'
            ),
          ],
        )
      end
    end

    # @param kind select [stack,flow,form,actions,links]
    # @param gap number
    # @param align select [~,start,center,end,stretch]
    def workbench(kind: :stack, gap: 12, align: nil)
      render(NDS::StackComponent.new(kind: kind&.to_sym, gap:, align: align&.to_sym)) do
        safe_join(
          ['One', 'Two', 'Three'].map { |label| content_tag(:div, label) },
        )
      end
    end
  end
end
