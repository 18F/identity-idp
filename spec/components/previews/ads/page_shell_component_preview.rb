class ADS::PageShellComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param title text
  # @param subtitle text
  # @param width select [form,wide]
  # @param spacious toggle
  # @param hide_chrome toggle
  # @param hide_footer toggle
  def workbench(
    title: 'Sign in',
    subtitle: 'Enter your email address to continue.',
    width: :form,
    spacious: false,
    hide_chrome: false,
    hide_footer: false
  )
    render(
      ADS::PageShellComponent.new(
        width: width,
        density: (:spacious if spacious),
        hide_chrome: hide_chrome,
        hide_footer: hide_footer,
      ),
    ) do |shell|
      shell.with_body do
        render(ADS::FormPageComponent.new(title: title, subtitle: subtitle)) do |page|
          page.with_body do
            tag.p('Form fields go here.', class: 'ads-auth__intro-description')
          end
          page.with_actions do
            render(ButtonComponent.new(variant: :primary).with_content('Continue'))
          end
        end
      end
    end
  end
end
