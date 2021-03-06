# ONLY created in BikeCreator in production
class CreationState < ApplicationRecord
  ORIGIN_ENUM = {
    web: 0,
    embed: 1,
    embed_extended: 2,
    embed_partial: 3,
    api_v1: 4,
    api_v2: 5,
    bulk_import_worker: 6,
    organization_form: 7,
    creator_unregistered_parking_notification: 8,
    impound_import: 9
  }.freeze

  belongs_to :bike
  belongs_to :organization # Duplicates Bike#creation_organization_id - generally, use the creation_state organization
  belongs_to :creator, class_name: "User"
  belongs_to :bulk_import

  enum status: Bike::STATUS_ENUM
  enum pos_kind: Organization::POS_KIND_ENUM
  enum origin_enum: ORIGIN_ENUM

  before_validation :set_calculated_attributes
  after_create :create_bike_organization
  after_save :set_reflexive_association

  attr_accessor :can_edit_claimed

  # TODO: switch to enum keys (and remove non-enum attribute)
  # Also need to reconcile bike_status and origin creator_unregistered_parking_notification
  def self.origins
    %w[web embed embed_extended embed_partial api_v1 api_v2 bulk_import_worker organization_form unregistered_parking_notification impound_import].freeze
  end

  def creation_description
    if is_pos
      pos_kind.to_s.gsub("_pos", "").humanize
    elsif is_bulk
      "bulk import"
    elsif origin.present?
      return "org reg" if %w[embed_extended organization_form].include?(origin)
      return "landing page" if origin == "embed_partial"
      return "parking notification" if origin == "unregistered_parking_notification"
      origin.humanize.downcase
    end
  end

  def set_calculated_attributes
    self.origin = "web" unless self.class.origins.include?(origin)
    self.status ||= bike&.status
    self.origin_enum ||= if status == "unregistered_parking_notification" || origin == "unregistered_parking_notification"
      "creator_unregistered_parking_notification"
    else
      origin
    end
    self.pos_kind ||= calculated_pos_kind
    # Hack, only set on create. TODO: should be passed from pos integration
    # currently, lightspeed is using API v1, so that's where this needs to come from
    self.is_new = pos_kind != "no_pos" if id.blank?
  end

  def create_bike_organization
    return true unless organization.present?
    unless BikeOrganization.where(bike_id: bike_id, organization_id: organization_id).present?
      BikeOrganization.create(bike_id: bike_id, organization_id: organization_id, can_edit_claimed: can_edit_claimed)
    end
    if organization.parent_organization.present? && BikeOrganization.where(bike_id: bike_id, organization_id: organization.parent_organization_id).blank?
      BikeOrganization.create(bike_id: bike_id, organization_id: organization.parent_organization_id, can_edit_claimed: can_edit_claimed)
    end
  end

  def set_reflexive_association
    # TODO: stop doing this, it was suppose to be temporary, to make migration easier
    b = Bike.unscoped.where(id: bike_id).first
    b.update_attribute(:creation_state_id, id) if b.present? && b&.creation_state_id != id
    true
  end

  # TODO: added in #1879, but turns out it hasn't been happening for a while
  # - last duplicate occurred in > 12 months ago - so after removing them, check if still a problem, probably can remove method
  def duplicates
    self.class.where(bike_id: bike_id).where("id > ?", id)
  end

  private

  def calculated_pos_kind
    if bulk_import&.ascend?
      self.is_pos = true # Lazy hack, could be improved
      "ascend_pos"
    elsif is_pos
      "lightspeed_pos"
    else
      "no_pos"
    end
  end
end
