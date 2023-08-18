require 'rails_helper'

RSpec.describe 'BIMI logo' do
  it 'is available' do
    # If you're troubleshooting this spec, there's a good chance you're trying to remove a file that
    # appears to be unused. This comment is here to assure you that it is in-fact used, referenced
    # as part of the BIMI DMARC records associated with the Login.gov domain. The image should not
    # be removed as long as it's referenced by those records.
    get '/images/login-icon-bimi.svg'

    expect(response.status).to eq(200)
  end
end
