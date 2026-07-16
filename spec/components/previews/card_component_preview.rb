class CardComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param title text
  # @param description text
  # @param url text
  # @param padding select [default,compact]
  def workbench(
    title: 'Authentication app',
    description: 'Get a one-time code from an app on your device',
    url: nil,
    padding: :default
  )
    render CardComponent.new(
      url: url.presence,
      padding: padding.to_sym,
    ) do |card|
      if url.present?
        card.with_trailing { render IconComponent.new(icon: :chevron_right, size: 20) }
      end

      tag.div(class: 'ads-card__stack') do
        safe_join(
          [
            tag.p(title, class: 'ads-card__title'),
            tag.p(description, class: 'ads-card__description'),
          ],
        )
      end
    end
  end
end
