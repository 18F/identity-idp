RSpec::Matchers.define :label_required_fields do
  elements = []

  match do |page|
    page.all(:css, 'input[required]').each do |input|
      elements << input if input['aria-invalid'].blank?
    end
    elements.empty?
  end

  failure_message do |page|
    elem_summaries = elements.map do |elem|
      [
        elem.tag_name,
        elem[:name] ? " name=#{elem[:name]} " : nil,
        elem[:class].split(' ').map { |c| ".#{c}" },
      ].join('')
    end.join(', ')

    <<-STR.squish
      On #{page.current_path} found #{elements.count} elements with
      required=true but missing aria-invalid=false (#{elem_summaries})
    STR
  end
end

RSpec::Matchers.define :have_description do |description|
  def descriptors(element)
    element['aria-describedby']&.
      split(' ')&.
      map { |descriptor_id| rendered.at_css("##{descriptor_id}")&.text }
  end

  match { |element| descriptors(element)&.include?(description) }

  failure_message do |element|
    <<-STR.squish
      Expected element would have `aria-describedby` description "#{description}".
      Found #{descriptors(element)}.
    STR
  end
end

RSpec::Matchers.define :be_uniquely_titled do
  # Attempts to validate conformance to WCAG Success Criteria 2.4.2: Page Titled
  #
  # Visiting a page with the default app name title is considered a failure, and should be resolved
  # by providing a distinct description for the page using the `:title` content block.
  #
  # https://www.w3.org/WAI/WCAG21/Understanding/page-titled.html

  match do |page|
    page.title.present? && page.title.strip != APP_NAME
  end

  failure_message do |page|
    "Page '#{page.current_path}' should have a unique and descriptive title. Found '#{page.title}'."
  end
end
