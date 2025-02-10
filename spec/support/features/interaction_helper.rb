module InteractionHelper
  def click_spinner_button_and_wait(...)
    click_on(...)
    wait_for_content_to_disappear do
      expect(page).to have_no_css('lg-spinner-button.spinner-button--spinner-active', wait: 10)
    end
  end

  def wait_for_content_to_disappear
    yield
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    # A StaleElementReferenceError means that the context the element
    # was in has disappeared, which means the element is gone too.
  rescue Selenium::WebDriver::Error::UnknownError => e
    # We sometimes see "UnknownError" with an error message that is similar to a
    # StaleElementReferenceError, but have not been able to resolve it and are ignoring it
    # for now.
    raise e if !e.message.include?('Node with given id does not belong to the document')
  end

  def assert_navigation(expected_navigation = true)
    page.execute_script(<<~JS)
      window.samePage = true;
      addEventListener("beforeunload", () => delete window.samePage);
    JS

    yield

    did_navigate = !page.evaluate_script('window.samePage')
    error_message = if expected_navigation
                      'Expected navigation or form submission, but page did not change'
                    else
                      'Expected no navigation or form submission, but page changed'
                    end

    expect(did_navigate).to eq(expected_navigation), error_message
  end
end
