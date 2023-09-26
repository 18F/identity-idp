class Events::Profile::BaseEvent < Events::BaseEvent
  self.table_name = 'profile_events'

  belongs_to :profile, class_name: '::Profile', autosave: false
end
