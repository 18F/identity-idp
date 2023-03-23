# Feel free to propose a better name.
# We need to stash the user's irs_session_id when a user is flagged for fraud.
# The IRS asked us to store our session ID, too.
# We give this back to them when a user is manually approved/rejected.
# It COULD make sense to put other stuff here and make this the primary way of tracking this,
# but the immediate need is to just have a way to link this data back to a user before there
# is a ServiceProviderIdentity.
class FraudEvent < ApplicationRecord
  belongs_to :user
end
