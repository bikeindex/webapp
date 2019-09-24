class ExternalRegistryBike < ActiveRecord::Base
  belongs_to :external_registry

  validates \
    :external_id,
    :external_registry,
    :serial_number,
    presence: true

  validates :external_id, uniqueness: { scope: :external_registry }

  default_scope { includes(:external_registry) }

  before_save :normalize_serial_number

  def self.registered_in_country(iso: "NL")
    country_id = Country.where(iso: iso.upcase).select(:id)

    includes(external_registry: :country)
      .where(external_registries: { country_id: country_id })
  end

  def self.find_or_search_registry_for(serial_number:)
    matches = ExternalRegistryBike.where(serial_number: serial_number)
    return matches if matches.any?

    matches = ExternalRegistry.search_for_bikes_with(serial_number: serial_number)

    exact_matches = matches.where(serial_number: serial_number)
    return exact_matches if exact_matches.any?

    matches
  end

  def type
    cycle_type
  end

  def stolen
    status&.downcase == "stolen"
  end

  def registry_name
    external_registry&.name
  end

  def registry_url
    external_registry&.url
  end

  def title_string
    "#{mnfg_name} #{frame_model}"
  end

  def mnfg_name
    self[:mnfg_name]&.titleize
  end

  def frame_model
    self[:frame_model]&.titleize
  end

  def frame_colors
    self[:frame_colors]
      &.split(/\s*,\s*/)
      &.map(&:titleize)
  end

  def source_name
    self[:source_name]&.titleize
  end

  def status
    self[:status]&.titleize
  end

  private

  def normalize_serial_number
    self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
  end
end
