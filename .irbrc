IRB.conf[:USE_AUTOCOMPLETE] = false

on_deployed_box = File.directory?('/srv/idp/releases/')

IRB.conf[:SAVE_HISTORY] = on_deployed_box ? 0 : 1000
