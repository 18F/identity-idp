module AccordionHelper
  # Options hash values: wrapper_css, hide_header, hide_close_link
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
