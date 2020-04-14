# frozen_string_literal: true

class ParkingNotification < ActiveRecord::Base
  KIND_ENUM = { appears_abandoned_notification: 0, parked_incorrectly_notification: 1, impound_notification: 2 }.freeze
  STATUS_ENUM = { current: 0, superseded: 1, impounded: 2, retrieved: 3 }.freeze
  RETRIEVAL_KIND_ENUM = { organization_recovery: 0, link_token_recovery: 1, user_recovery: 2 }.freeze

  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :impound_record
  belongs_to :initial_record, class_name: "ParkingNotification"
  belongs_to :retrieved_by, class_name: "User"
  belongs_to :country
  belongs_to :state

  has_many :repeat_records, class_name: "ParkingNotification", foreign_key: :initial_record_id

  validates_presence_of :bike_id, :user_id
  validate :location_present, on: :create

  before_validation :set_calculated_attributes
  after_create :process_notification

  enum kind: KIND_ENUM
  enum status: STATUS_ENUM
  enum retrieval_kind: RETRIEVAL_KIND_ENUM

  # TODO: location refactor - switch to Geocodeable
  geocoded_by :geocode_data

  attr_accessor :is_repeat, :use_entered_address

  scope :active, -> { where(status: active_statuses) }
  scope :resolved, -> { where(status: resolved_statuses) }
  scope :initial_records, -> { where(initial_record_id: nil) }
  scope :repeat_records, -> { where.not(initial_record_id: nil) }
  scope :with_impound_record, -> { where.not(impound_record_id: nil) }
  scope :email_success, -> { where(delivery_status: "email_success") }
  scope :send_email, -> { where.not(unregistered_bike: true) }
  scope :unregistered_bike, -> { where(unregistered_bike: true) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.active_statuses; %w[current superseded] end

  def self.resolved_statuses; STATUS_ENUM.keys.map(&:to_s) - active_statuses end

  def self.kinds_humanized
    {
      appears_abandoned_notification: "Appears abandoned",
      parked_incorrectly_notification: "Parked incorrectly",
      impound_notification: "Impounded",
    }
  end

  def self.associated_notifications(id, initial_record_id)
    potential_id_matches = [id, initial_record_id].compact
    return none unless potential_id_matches.any?
    where(initial_record_id: potential_id_matches).where.not(id: id)
      .or(where(id: initial_record_id))
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike; @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil end

  def active?; self.class.active_statuses.include?(status) end

  def resolved?; !active? end

  def initial_record?; initial_record_id.blank? end

  def repeat_record?; initial_record_id.present? end

  def owner_known?; !unregistered_bike? && (bike&.owner_email).present? end

  def send_email?; owner_known? end

  def show_address; !hide_address end

  def kind_humanized; self.class.kinds_humanized[kind.to_sym] end

  def can_be_repeat?; potential_initial_record.present? end

  def email; bike.owner_email end

  def reply_to_email; organization&.auto_user&.email || user&.email end

  def current_associated_notification; current? ? self : associated_notifications.order(:id).last end

  # Fallback to created_at because something is busted and we need this to exist sometimes
  def impounded_at; impounded? ? impound_record&.created_at || created_at : nil end

  # Only initial_record and repeated records - does not include any resolved parking notifications
  def associated_notifications; self.class.associated_notifications(id, initial_record_id) end

  # All get applied
  def associated_retrieved_notification
    return nil unless retrieved?
    retrieved_by_id.present? ? self : associated_notifications.where.not(retrieved_by_id: nil).first
  end

  def earlier_bike_notifications
    notifications = ParkingNotification.where(organization_id: organization&.id, bike_id: bike&.id)
    id.present? ? notifications.where("id < ?", id) : notifications
  end

  def potential_initial_record
    return earlier_bike_notifications.initial_records.order(:id).last unless id.blank?
    # If this is a new record, we the record needs to be current
    earlier_bike_notifications.current.initial_records.order(:id).last
  end

  def likely_repeat?
    return false unless can_be_repeat?
    # We know there has to be a potential initial record if can_be_repeat,
    # so it doesn't matter if we scope to current on new records or not
    earlier_bike_notifications.maximum(:created_at) > (created_at || Time.current) - 1.month
  end

  def repeat_number
    return 0 unless repeat_record?
    ParkingNotification.where(initial_record_id: initial_record_id)
                       .where("id < ?", id).count + 1
  end

  def notification_number; repeat_number + 1 end

  def mark_retrieved!(r_user_id, r_kind, r_at = nil)
    return self if retrieved?
    update_attributes!(retrieved_by_id: r_user_id,
                       retrieval_kind: r_kind,
                       retrieved_at: r_at || Time.current)
    process_notification
    self
  end

  # TODO: location refactor - copied method from stolen
  # ... however, because this has a hide_address attr, which means by default we show addresses
  def address(skip_default_country: true, force_show_address: false)
    country_string =
      if country&.iso&.in?(%w[US USA])
        skip_default_country ? nil : "USA"
      else
        country&.iso
      end

    [
      (force_show_address || show_address) ? street : nil,
      city,
      [state&.abbreviation, zipcode].reject(&:blank?).join(" "),
      country_string,
    ].reject(&:blank?).join(", ")
  end

  # Proxy method for now
  def display_address(skip_default_country: true, force_show_address: false)
    address(skip_default_country: skip_default_country, force_show_address: force_show_address)
  end

  def set_location_from_organization
    self.country_id = organization&.country&.id
    self.city = organization&.city
    self.zipcode = organization&.zipcode
    self.state_id = organization&.state&.id
  end

  # TODO: location refactor, use the same attributes for all location models
  def set_calculated_attributes
    self.initial_record_id ||= potential_initial_record&.id if is_repeat
    self.status = calculated_status
    # Only set unregistered_bike on creation
    self.unregistered_bike = calculated_unregistered_parking_notification if id.blank?
    # generate retrieval token after checking if unregistered_bike
    self.retrieval_link_token ||= SecurityTokenizer.new_token if current? && send_email?
    # We need to geocode on creation, unless all the attributes are present
    return true if id.present? && street.present? && latitude.present? && longitude.present?
    if !use_entered_address && latitude.present? && longitude.present?
      addy_hash = Geohelper.formatted_address_hash(Geohelper.reverse_geocode(latitude, longitude))
      self.street = addy_hash["address"]
      self.city = addy_hash["city"]
      self.zipcode = addy_hash["zipcode"]
      self.country = Country.fuzzy_find(addy_hash["country"])
      self.state = State.fuzzy_find(addy_hash["state"])
    else
      coordinates = Geohelper.coordinates_for(address)
      self.attributes = coordinates if coordinates.present?
      self.location_from_address = true
    end
  end

  def location_present
    # in case geocoder is failing (which happens sometimes), permit if either is present
    return true if latitude.present? && longitude.present? || address.present?
    self.errors.add(:address, :address_required)
  end

  def title
    if appears_abandoned_notification?
      "Your #{bike&.type || "Bike"} appears to be abandoned"
    elsif parked_incorrectly_notification?
      "Your #{bike&.type || "Bike"} is parked incorrectly"
    elsif impounded?
      "Your #{bike&.type || "Bike"} was impounded"
    end
  end

  def process_notification
    # Update the bike immediately, inline
    bike&.set_address
    bike&.update(updated_at: Time.current)
    ProcessParkingNotificationWorker.perform_async(id)
  end

  # new_attrs needs to include kind and user_id. It can include additional attrs if they matter
  def retrieve_or_repeat_notification!(new_attrs)
    new_attrs = new_attrs.with_indifferent_access
    if new_attrs.with_indifferent_access[:kind] == "mark_retrieved"
      mark_retrieved!(new_attrs[:user_id], "organization_recovery")
    else
      return self unless active?
      attrs = attributes.except("id", "internal_notes", "created_at", "updated_at", "message",
                                "location_from_address", "retrieval_link_token", "delivery_status")
                        .merge(new_attrs)
      attrs["initial_record_id"] ||= id
      ParkingNotification.create!(attrs)
    end
  end

  private

  def calculated_unregistered_parking_notification
    bike&.unregistered_parking_notification?
  end

  def calculated_status
    return "impounded" if impound_notification? || impound_record_id.present?
    return "retrieved" if retrieved_at.present? || associated_notifications.retrieved.any?
    associated_notifications.where("id > ?", id).any? ? "superseded" : "current"
  end
end
