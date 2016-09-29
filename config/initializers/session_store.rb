require 'active_record/session_store'

Rails.application.config.session_store :active_record_store, key: '_upaya_session'
ActiveRecord::SessionStore::Session.serializer = SessionEncryptor
