module AccordionHelper
  # Options hash values: heading_level
  def accordion(target_id, header_text, options = {}, &block)
    locals = {
      target_id: target_id,
      header_text: header_text,
      options: options,
    }

    render(layout: 'shared/accordion', locals: locals, &block)
  end
end

ActionView::Base.send :include, AccordionHelper
