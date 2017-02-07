module AccordionHelper
  def accordion(target_id, header_text, &block)
    locals = {
      target_id: target_id,
      header_text: header_text,
    }

    render(layout: 'shared/accordion', locals: locals, &block)
  end
end

ActionView::Base.send :include, AccordionHelper
