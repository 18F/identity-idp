class ProfileEvent < Events::Profile::BaseEvent
  belongs_to :profile, optional: true
end
