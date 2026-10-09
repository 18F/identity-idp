# frozen_string_literal: true

# The RFC 7638 thumbprint of the DPoP key a public-client service provider named in its
# authorization request (`dpop_jkt`, RFC 9449 §10). The authorization code issued for that
# request can be redeemed only with a proof signed by that key, and the access token issued at
# the code exchange is bound to it. Null for confidential clients and for public clients not
# approved for delegated access, whose tokens are bearer tokens.
class AddDpopJktToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :dpop_jkt, :string, comment: 'sensitive=false'
  end
end
