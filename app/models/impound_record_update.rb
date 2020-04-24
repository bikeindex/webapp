class ImpoundRecordUpdate < ApplicationRecord
  # These statuses overlap with impound_records! The resolved statuses need to match up
  KIND_ENUM = { note: 0, move_location: 1, retrieved_by_owner: 2, removed_from_bike_index: 3, transferred_to_new_owner: 4 }.freeze

  belongs_to :impound_record
  belongs_to :user
  belongs_to :location

  validates_presence_of :impound_record_id, :user_id
  validates_presence_of :transfer_email, if: :transferred_to_new_owner?

  after_commit :update_associations

  enum kind: KIND_ENUM

  scope :active, -> { where(kind: active_kinds) }
  scope :resolved, -> { where(kind: resolved_kinds) }
  scope :with_location, -> { where.not(location_id: nil) }
  scope :unresolved, -> { where(resolved: false) } # Means the update worker hasn't taken care of them

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.active_kinds; %w[note move_location] end

  def self.resolved_kinds; kinds - active_kinds end

  def self.kinds_without_location; kinds - ["move_location"] end

  def self.kinds_humanized
    {
      note: "note",
      move_location: "move location",
      retrieved_by_owner: "retrieved by owner",
      removed_from_bike_index: "removed from Bike Index",
      transferred_to_new_owner: "transferred to new owner",
    }
  end

  def active?; self.class.active_kinds.include?(kind) end

  def resolved?; !active? end

  def kind_humanized; self.class.kinds_humanized[kind.to_sym] end

  def update_associations
    impound_record&.update(updated_at: Time.current)
  end
end
