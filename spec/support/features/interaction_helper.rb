module InteractionHelper
  def click_spinner_button_and_wait(...)
    click_on(...)
    wait_for_content_to_disappear do
      expect(page).to have_no_css('lg-spinner-button.spinner-button--spinner-active', wait: 10)
    end
  end

  def wait_for_content_to_disappear do
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
end
