RSpec::Matchers.define :have_valid_idrefs do
  invalid_idref_messages = []

  match do |page|
    ['aria-describedby', 'aria-labelledby'].each do |idref_attribute|
      page.all(:css, "[#{idref_attribute}]").each do |element|
        element[idref_attribute].split(' ').each do |referenced_id|
          page.find_by_id(referenced_id, visible: :all)
        end
      rescue Capybara::ElementNotFound
        invalid_idref_messages << "[#{idref_attribute}=\"#{element[idref_attribute]}\"]"
      end
    end

    invalid_idref_messages.blank?
  end

  failure_message do |page|
    <<~STR
      Found #{invalid_idref_messages.count} elements with invalid ID reference links:

      #{invalid_idref_messages.join("\n")}
    STR
  end
end

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

RSpec::Matchers.define :have_valid_markup do
  def page_html
    if page.driver.is_a?(Capybara::Selenium::Driver)
      # Here be dragons:
      # 1. ChromeDriver repairs most invalid HTML, thus defeating the purpose of this test
      # 2. Switching drivers does not preserve the original session, hence the cookie management
      # 3. The domain name differs between Rack and ChromeDriver testing environments
      # 4. Methods stubbed for JS tests carry over when switching drivers (see `rails_helper.rb`)
      cookies = page.driver.browser.send(:bridge).cookies
      session_value = cookies.find { |c| c['name'] == '_identity_idp_session' }&.[]('value')
      original_path_with_params = URI.parse(current_url).request_uri
      Capybara.using_driver(:desktop_rack_test) do
        domain_name = IdentityConfig.store.domain_name
        default_url_options = Rails.application.routes.default_url_options
        allow(IdentityConfig.store).to receive(:domain_name).and_call_original
        allow(Rails.application.routes).to receive(:default_url_options).and_call_original
        page.driver.browser.set_cookie "_identity_idp_session=#{session_value}" if session_value
        page.driver.get(original_path_with_params)
        allow(IdentityConfig.store).to receive(:domain_name).and_return(domain_name)
        allow(Rails.application.routes).to receive(:default_url_options).
          and_return(default_url_options)
        page.html
      end
    else
      page.html
    end
  end

  def page_markup_syntax_errors
    return @page_markup_syntax_errors if defined?(@page_markup_syntax_errors)
    @page_markup_syntax_errors = Nokogiri::HTML5(page_html, max_errors: 20).errors
  end

  match { |_page| page_markup_syntax_errors.blank? }

  failure_message do |page|
    <<~STR
      Expected page to have valid markup. Found syntax errors:

      #{page_markup_syntax_errors.map(&:inspect).join("\n")}
    STR
  end
end

RSpec::Matchers.define :have_description do |description|
  def descriptors(element)
    element['aria-describedby']&.
      split(' ')&.
      map { |descriptor_id| page.find("##{descriptor_id}")&.text }
  end

  match { |element| descriptors(element)&.include?(description) }

  failure_message do |element|
    <<-STR.squish
      Expected element would have `aria-describedby` description "#{description}".
      Found #{descriptors(element)}.
    STR
  end
end

RSpec::Matchers.define :have_name do |name|
  # Implements a best effort approximation of W3C Accessible Name and Description Computation 1.2
  # See: https://www.w3.org/TR/accname-1.2/#mapping_additional_nd_te
  #
  # In the future, consider implementing using Chrome DevTools Accessibility features. At time of
  # writing, these are experimental and return a `nil` value in local testing.
  #
  # See: https://chromedevtools.github.io/devtools-protocol/tot/Accessibility/
  #
  # We can use the Capybara driver "bridge" to call these commands.
  #
  # Example: https://github.com/18F/identity-idp/blob/3c7d3be/spec/support/features/browser_emulation_helper.rb

  def hidden_name(element)
    # "If the current node is hidden [...] return the empty string."
    #
    # Note: This should also check page visibility, but Capybara's Element#visible? considers off-
    # screen elements as non-visible, which is not the same as how it's considered for names.
    '' if element['aria-hidden'] == 'true'
  end

  def aria_labelledby_name(element)
    # "if computing a name, and the current node has an aria-labelledby attribute that contains at
    # least one valid IDREF, and the current node is not already part of an aria-labelledby
    # traversal, process its IDREFs in the order they occur"
    valid_labels = element['aria-labelledby']&.
      split(' ')&.
      map { |label_id| page.find("##{label_id}")&.text }&.
      compact

    valid_labels.join('') if valid_labels.present?
  end

  def aria_label_name(element)
    # "Otherwise, if computing a name, and if the current node has an aria-label attribute whose
    # value is not the empty string, nor, when trimmed of white space, is not the empty string:"
    element['aria-label']
  end

  def referenced_label_name(element)
    # "Otherwise, if the current node's native markup provides an attribute (e.g. title) or element
    # (e.g. HTML label) that defines a text alternative, return that alternative in the form of a
    # flat string as defined by the host language"
    descendent_name(page.find("label[for='#{element['id']}']"))
  rescue Capybara::ElementNotFound
    nil
  end

  def ancestor_label_text_name(element)
    # "Otherwise, if the current node is a control embedded within the label"
    descendent_name(element.find(:xpath, 'ancestor::label'))
  rescue Capybara::ElementNotFound
    nil
  end

  def descendent_name(element)
    # "Otherwise, if the current node is a descendant of an element whose Accessible Name or
    # Accessible Description is being computed, and contains descendants, proceed to 2F.i."
    #
    # Note: There should probably be some recursion here with the other methods, but Capybara only
    # allows us to work with elements and not text nodes, which presents a challenge for computing
    # the descendent name.
    visible_text_js = <<~JS
      (function getVisibleChildNodeText(childNodes) {
          return Array.from(childNodes).flatMap((child) => {
              switch (child.nodeType) {
                  case Node.TEXT_NODE:
                      return child.nodeValue;
                  case Node.ELEMENT_NODE:
                      if (child.getAttribute('aria-hidden') !== 'true') {
                        return child.nodeName === 'IMG' ?
                          child.getAttribute('alt') :
                          getVisibleChildNodeText(child.childNodes);
                      }
              }
          });
      })(arguments[0].childNodes).filter(Boolean).join('').trim();
    JS

    page.evaluate_script(visible_text_js, element)
  end

  def computed_name(element)
    hidden_name(element) ||
      aria_labelledby_name(element) ||
      aria_label_name(element) ||
      referenced_label_name(element) ||
      ancestor_label_text_name(element)
  end

  match { |element| computed_name(element) == name }

  failure_message do |element|
    <<-STR.squish
      Expected element would have computed name "#{name}".
      Found #{computed_name(element)}.
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

def expect_page_to_have_no_accessibility_violations(page, validate_markup: true)
  expect(page).to be_axe_clean.according_to :section508, :"best-practice", :wcag21aa
  expect(page).to have_valid_idrefs
  expect(page).to label_required_fields
  expect(page).to be_uniquely_titled
  expect(page).to have_valid_markup if validate_markup
end

def activate_skip_link
  page.evaluate_script('document.activeElement = null') if page.active_element.tag_name != 'body'
  page.active_element.send_keys(:tab)
  expect(page.active_element).to have_content(t('shared.skip_link'), wait: 5)
  page.active_element.send_keys(:enter)
end
