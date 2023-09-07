# rubocop:disable Metrics/BlockLength
# rubocop:disable Style/StringLiterals
ActiveRecord::Schema.define do
  create_table "event_records", force: true do |t|
    t.uuid "aggregate_id", null: false
    t.integer "sequence_number", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "event_json", null: false
    t.integer "command_record_id", null: false
    t.integer "stream_record_id", null: false
  end

  execute <<~SQL
    CREATE UNIQUE INDEX unique_event_per_aggregate
    ON event_records (
      aggregate_id,
      sequence_number,
      (
        CASE event_type
        WHEN 'Sequent::Core::SnapshotEvent'
        THEN 0
        ELSE 1
        END
      )
    )
  SQL
  execute <<~SQL
    CREATE INDEX snapshot_events
    ON event_records (aggregate_id, sequence_number DESC)
    WHERE event_type = 'Sequent::Core::SnapshotEvent'
  SQL

  add_index "event_records", ["command_record_id"], name: "index_event_records_on_command_record_id"
  add_index "event_records", ["event_type"], name: "index_event_records_on_event_type"
  add_index "event_records", ["created_at"], name: "index_event_records_on_created_at"

  create_table "command_records", force: true do |t|
    t.string "user_id"
    t.uuid "aggregate_id"
    t.string "command_type", null: false
    t.string "event_aggregate_id"
    t.integer "event_sequence_number"
    t.text "command_json", null: false
    t.datetime "created_at", null: false
  end

  add_index "command_records", ["event_aggregate_id", 'event_sequence_number'],
            name: "index_command_records_on_event"

  create_table "stream_records", force: true do |t|
    t.datetime "created_at", null: false
    t.string "aggregate_type", null: false
    t.uuid "aggregate_id", null: false
    t.integer "snapshot_threshold"
  end

  add_index "stream_records", ["aggregate_id"], name: "index_stream_records_on_aggregate_id",
                                                unique: true
  execute <<~SQL
    ALTER TABLE event_records
    ADD CONSTRAINT command_fkey FOREIGN KEY (command_record_id) REFERENCES command_records (id)
  SQL
  execute <<~SQL
    ALTER TABLE event_records
    ADD CONSTRAINT stream_fkey FOREIGN KEY (stream_record_id) REFERENCES stream_records (id)
  SQL
end
# rubocop:enable Style/StringLiterals
# rubocop:enable Metrics/BlockLength
