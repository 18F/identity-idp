require File.expand_path(File.dirname(__FILE__) + '/acceptance_helper')

feature 'IdpController' do

  scenario 'Login via default signup page' do
    saml_request = make_saml_request("http://foo.example.com/saml/consume")
    visit "/saml/auth?SAMLRequest=#{CGI.escape(saml_request)}"
    fill_in 'Email', :with => "brad.copa@example.com"
    fill_in 'Password', :with => "okidoki"
    click_button 'Sign in'
    click_button 'Submit'   # simulating onload
    current_url.should == 'http://foo.example.com/saml/consume'
    page.should have_content "brad.copa@example.com"
  end

end