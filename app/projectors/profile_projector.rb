class ProfileProjector < Sequent::Projector
  manages_tables ProfileRecord

  on ProfileCreated do |event|
    create_record(ProfileRecord, aggregate_id: event.aggregate_id)
  end

  on ProfileMinted do |event|
    update_all_records(
      ProfileRecord, { aggregate_id: event.aggregate_id },
      event.attributes.slice(:author)
    )
  end
end
