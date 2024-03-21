class CreateNewDeviceAlert < ApplicationJob
  queue_as :long_running

  # on 5 minute interval - look at User table for
  # existence of sign_in_new_device as a date and not null
  # ...
end