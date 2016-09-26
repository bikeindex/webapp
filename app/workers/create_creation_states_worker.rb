class CreateCreationStatesWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, retry: false

  def perform(offset)
    current = offset - 1
    while current < offset + 101
      current += 1
      bike = Bike.unscoped.where(id: current).first
      next unless bike.present?
      creation_state = CreationState.where(bike_id: bike.id).first
      creation_state ||= CreationState.new(bike_id: bike.id)
      creation_state.is_new ||= bike.registered_new || false
      creation_state.is_pos ||= bike.registered_new || false
      next if creation_state.id.present? && creation_state.creator_id.present?
      creation_state.update_attributes(creator_id: bike.creator_id, organization_id: bike.creation_organization_id)
    end
  end
end