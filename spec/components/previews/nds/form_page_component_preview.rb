module NDS
  # Net-new NDS page scaffold; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  class FormPageComponentPreview < BaseComponentPreview
    include ActionView::Helpers::TagHelper

    def default
      render(
        NDS::FormPageComponent.new(title: 'Sign in', subtitle: 'Enter your email address.'),
      ) do |c|
        c.with_body { example_body }
        c.with_actions { example_actions }
      end
    end

    def with_alert
      render(NDS::FormPageComponent.new(title: 'Sign in')) do |c|
        c.with_alert do
          content_tag(:div, 'Your session expired.', class: 'usa-alert usa-alert--warning')
        end
        c.with_body { example_body }
      end
    end

    def with_media
      render(NDS::FormPageComponent.new(title: 'Verify your identity')) do |c|
        c.with_media { content_tag(:div, 'ILLUSTRATION', class: 'auth__media-example') }
        c.with_body { example_body }
      end
    end

    def with_divider
      render(NDS::FormPageComponent.new(title: 'Sign in', divider: true)) do |c|
        c.with_body { example_body }
        c.with_actions { example_actions }
      end
    end

    # @param title text
    # @param subtitle text
    # @param alert_position select [above,below]
    # @param divider toggle
    def workbench(
      title: 'Sign in',
      subtitle: 'Enter your email address and password.',
      alert_position: :above,
      divider: false
    )
      render(
        NDS::FormPageComponent.new(
          title:,
          subtitle:,
          alert_position: alert_position&.to_sym,
          divider:,
        ),
      ) do |c|
        c.with_alert { content_tag(:div, 'Heads up.', class: 'usa-alert usa-alert--info') }
        c.with_body { example_body }
        c.with_actions { example_actions }
      end
    end

    private

    def example_body
      content_tag(:p, 'Enter your email address and password to continue.')
    end

    def example_actions
      content_tag(:button, 'Sign in', type: 'submit', class: 'usa-button')
    end
  end
end
