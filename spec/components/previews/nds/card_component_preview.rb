module NDS
  # Previews for NDS::CardComponent. Intended to be viewed in the nds bucket
  # (?ui_test_bucket=nds) so the card is painted with the NDS styles.
  class CardComponentPreview < BaseComponentPreview
    include ActionView::Helpers::TagHelper

    # @!group Preview
    def default
      render(NDS::CardComponent.new) { 'A plain card container.' }
    end

    def compact
      render(NDS::CardComponent.new(padding: :compact)) { 'A compact card.' }
    end

    def interactive_link
      render(NDS::CardComponent.new(url: '#')) { 'A card that links somewhere.' }
    end

    def button
      render(NDS::CardComponent.new(button: true)) { 'A card that acts as a button.' }
    end

    def form_action
      render(NDS::CardComponent.new(url: '#', method: :post)) { 'A card that submits a form.' }
    end

    def with_trailing
      render(NDS::CardComponent.new(url: '#')) do |card|
        card.with_trailing { content_tag(:span, '→') }
        'A card with a trailing element.'
      end
    end
    # @!endgroup

    # @param padding select [default,compact]
    # @param url text
    # @param button toggle
    # @param content text
    def workbench(padding: :default, url: '', button: false, content: 'Card content')
      render(
        NDS::CardComponent.new(padding: padding&.to_sym, url: url.presence, button:),
      ) { content }
    end
  end
end
