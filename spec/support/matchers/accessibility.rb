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
      required=true but missing aria-invalid (#{elem_summaries})
    STR
  end
end
