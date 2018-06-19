class RemoteSetting < ApplicationRecord
  validates :url, format: {
    with:
      %r{\A(https://raw.githubusercontent.com/18F/identity-idp/|https://login.gov).+\z},
  }
end
