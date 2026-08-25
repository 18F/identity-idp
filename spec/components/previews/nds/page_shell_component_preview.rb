module NDS
  # Net-new NDS page shell; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  #
  # The shell's default top chrome renders the shared government banner, which
  # needs full controller/session context not available to Lookbook previews,
  # so these scenarios hide the chrome and show the shell frame + footer. See
  # the Page Chrome preview for the chrome in isolation.
  class PageShellComponentPreview < BaseComponentPreview
    include ActionView::Helpers::TagHelper

    def default
      render(NDS::PageShellComponent.new(width: :form, hide_chrome: true)) do
        example_body
      end
    end

    def wide
      render(NDS::PageShellComponent.new(width: :wide, hide_chrome: true)) do
        example_body
      end
    end

    def spacious
      render(
        NDS::PageShellComponent.new(width: :form, density: :spacious, hide_chrome: true),
      ) do
        example_body
      end
    end

    def bare
      render(
        NDS::PageShellComponent.new(width: :form, hide_chrome: true, hide_footer: true),
      ) do
        example_body
      end
    end

    # @param width select [~,form,wide]
    # @param density select [~,spacious,mobile-compact,fullscreen]
    # @param align select [~,start,mobile-start,stretch]
    # @param surface select [~,overlay]
    # @param hide_footer toggle
    def workbench(
      width: :form,
      density: nil,
      align: nil,
      surface: nil,
      hide_footer: false
    )
      render(
        NDS::PageShellComponent.new(
          width: width&.to_sym,
          density: density&.to_sym,
          align: align&.to_sym,
          surface: surface&.to_sym,
          hide_chrome: true,
          hide_footer:,
        ),
      ) do
        example_body
      end
    end

    private

    def example_body
      safe_join(
        [
          content_tag(:h1, 'Sign in'),
          content_tag(:p, 'Enter your email address and password.'),
        ],
      )
    end
  end
end
