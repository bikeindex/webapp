class Bike < ActiveRecord::Base
  include ActiveModel::Dirty
  include BikeSearchable
  include BikeBuildable
  mount_uploader :pdf, PdfUploader
  process_in_background :pdf, CarrierWaveProcessWorker

  belongs_to :manufacturer
  belongs_to :primary_frame_color, class_name: 'Color'
  belongs_to :secondary_frame_color, class_name: 'Color'
  belongs_to :tertiary_frame_color, class_name: 'Color'
  belongs_to :handlebar_type
  belongs_to :rear_wheel_size, class_name: 'WheelSize'
  belongs_to :front_wheel_size, class_name: 'WheelSize'
  belongs_to :rear_gear_type
  belongs_to :front_gear_type
  belongs_to :frame_material
  belongs_to :propulsion_type
  belongs_to :cycle_type
  belongs_to :paint, counter_cache: true
  belongs_to :updator, class_name: 'User'
  belongs_to :invoice
  belongs_to :location
  belongs_to :current_stolen_record, class_name: 'StolenRecord'

  # has_many :bike_organizations, dependent: :destroy
  # has_many :organizations, through: :bike_organizations
  belongs_to :creator
  belongs_to :creation_organization

  belongs_to :creation_state, dependent: :destroy
  delegate :creation_state_creator, to: :creation_state, source: :creator
  has_one :creation_state_creation_organization, through: :creation_state, source: :organization
  has_many :stolen_notifications, dependent: :destroy
  has_many :stolen_records, dependent: :destroy
  has_many :other_listings
  has_many :normalized_serial_segments
  has_many :ownerships, dependent: :destroy
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :components, dependent: :destroy
  has_many :b_params, as: :created_bike
  has_many :duplicate_bike_groups, through: :normalized_serial_segments
  has_many :recovered_records, -> { recovered }, class_name: 'StolenRecord'

  accepts_nested_attributes_for :stolen_records
  accepts_nested_attributes_for :components, allow_destroy: true

  geocoded_by nil, latitude: :stolen_lat, longitude: :stolen_long
  after_validation :geocode, if: lambda { |o| false } # Never geocode, it's from stolen_record

  validates_presence_of :serial_number
  validates_presence_of :propulsion_type_id
  validates_presence_of :cycle_type_id
  validates_presence_of :creation_state_id
  validates_presence_of :manufacturer_id

  validates_uniqueness_of :card_id, allow_nil: true
  validates_presence_of :primary_frame_color_id

  attr_accessor :other_listing_urls, :date_stolen_input, :receive_notifications,
    :phone, :image, :b_param_id, :embeded,
    :embeded_extended, :paint_name, :bike_image_cache, :send_email,
    :marked_user_hidden, :marked_user_unhidden, :b_param_id_token, :creator_id

  default_scope { where(example: false).where(hidden: false).order("listing_order desc") }
  scope :stolen, -> { where(stolen: true) }
  scope :non_stolen, -> { where(stolen: false) }
  scope :with_serial, -> { where("serial_number != ?", "absent") }
  scope :non_recovered, -> { where(recovered: false) }

  include PgSearch
  pg_search_scope :pg_search, against: {
      serial_number: 'A',
      cached_data:   'B',
      all_description:   'C'
    }, using: { tsearch: { dictionary: "english", prefix: true } }

  pg_search_scope :admin_search,
    against: { owner_email: 'A' },
    associated_against: { ownerships: :owner_email, creator: :email },
    using: { tsearch: { dictionary: "english", prefix: true } }

  class << self
    def old_attr_accessible
      # made_without_serial - GUARANTEE there was no serial
      (%w(cycle_type_id manufacturer_id manufacturer_other serial_number 
        serial_normalized has_no_serial made_without_serial additional_registration
        manufacturer year thumb_path name stolen
        current_stolen_record_id recovered frame_material_id frame_model number_of_seats
        handlebar_type_id handlebar_type_other frame_size frame_size_number frame_size_unit
        rear_tire_narrow front_wheel_size_id rear_wheel_size_id front_tire_narrow 
        primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id paint_id paint_name
        propulsion_type_id propulsion_type_other zipcode country_id belt_drive
        coaster_brake rear_gear_type_slug rear_gear_type_id front_gear_type_slug front_gear_type_id description owner_email
        date_stolen_input receive_notifications phone creator creator_id image
        components_attributes b_param_id embeded embeded_extended example hidden
        card_id stock_photo_url pdf send_email other_listing_urls listing_order approved_stolen
        marked_user_hidden marked_user_unhidden b_param_id_token is_for_sale
        ).map(&:to_sym) + [stolen_records_attributes: StolenRecord.old_attr_accessible,
            components_attributes: Component.old_attr_accessible]).freeze
    end
    
    def text_search(query)
      query.present? ? pg_search(query) : all
    end

    def admin_text_search(query)
      query.present? ? admin_search(query) : all
    end
  end

  def get_listing_order
    return current_stolen_record.date_stolen.to_time.to_i.abs if stolen && current_stolen_record.present?
    t = updated_at.to_time.to_i/10000
    t = t/100 unless stock_photo_url.present? or public_images.present?
    t
  end

  def current_ownership
    ownerships && ownerships.last
  end

  def owner
    current_ownership && current_ownership.owner
  end

  def first_ownership
    ownerships.first
  end

  def first_owner_email
    first_ownership.owner_email
  end

  def current_owner_exists
    current_ownership && current_ownership.claimed
  end

  def can_be_claimed_by(u)
    !current_owner_exists && current_ownership && current_ownership.user == u
  end

  def user_hidden
    hidden && current_ownership && current_ownership.user_hidden
  end

  def fake_deleted
    hidden && !user_hidden
  end

  def visible_by(user=nil)
    return true unless hidden
    if user.present?
      return true if user.superuser
      return true if owner == user && user_hidden
    end
    false
  end

  def find_current_stolen_record
    stolen_records.last if stolen_records.any?
  end

  def title_string
    t = [year, mnfg_name, frame_model].join(' ')
    t += " #{type}" if type != "bike"
    Rails::Html::FullSanitizer.new.sanitize(t.gsub(/\s+/,' ')).strip
  end

  def video_embed_src
    if video_embed.present?
      code = Nokogiri::HTML(video_embed)
      src = code.xpath('//iframe/@src')
      if src[0]
        src[0].value
      end
    end
  end

  def validate_organization_id(organization_id)
    organization = Organization.friendly_find(organization_id)
    return true if organization && !organization.suspended?
    msg = organization ? "suspended and can't be used" : 'not found'
    errors.add(:organization, "#{organization_id} is #{msg}")
    false
  end

  before_save :set_mnfg_name
  def set_mnfg_name
    if manufacturer.name == 'Other' && manufacturer_other.present?
      n = Rails::Html::FullSanitizer.new.sanitize(manufacturer_other)
    else
      n = manufacturer.name.gsub(/\s?\([^\)]*\)/i,'')
    end
    self.mnfg_name = n.strip.truncate(60)
  end

  before_save :set_user_hidden
  def set_user_hidden
    if marked_user_hidden.present? && marked_user_hidden.to_s != '0'
      self.hidden = true
      current_ownership.update_attribute :user_hidden, true unless current_ownership.user_hidden
    elsif marked_user_unhidden.present? && marked_user_unhidden.to_s != '0'
      self.hidden = false
      current_ownership.update_attribute :user_hidden, false if current_ownership.user_hidden
    end
    true
  end

  before_save :normalize_attributes
  def normalize_attributes
    self.serial_number = 'absent' if serial_number.blank? || serial_number.strip.downcase == 'unknown'
    self.serial_normalized = SerialNormalizer.new(serial: serial_number).normalized
    if User.fuzzy_email_find(owner_email)
      self.owner_email = User.fuzzy_email_find(owner_email).email
    else
      self.owner_email = EmailNormalizer.normalize(owner_email)
    end
    true
  end

  def create_normalized_serial_segments
    SerialNormalizer.new(serial: serial_number).save_segments(id)
  end

  before_save :clean_frame_size
  def clean_frame_size
    return true unless frame_size.present? || frame_size_number.present?
    if frame_size.present? && frame_size.match(/\d+\.?\d*/).present?
      self.frame_size_number = frame_size.match(/\d+\.?\d*/)[0].to_f
    end

    unless frame_size_unit.present?
      if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          self.frame_size_unit = 'in'
        else
          self.frame_size_unit = 'cm'
        end
      else
        self.frame_size_unit = 'ordinal'
      end
    end

    if frame_size_number.present?
      self.frame_size = frame_size_number.to_s.gsub('.0','') + frame_size_unit
    else
      self.frame_size = case frame_size.downcase
      when /x*sma/, 'xs'
        'xs'
      when /sma/, 's'
        's'
      when /med/, 'm'
        'm'
      when /(lg)|(large)/, 'l'
        'l'
      when /x*l/, 'xl'
        'xl'
      else
        nil
      end
    end
    true
  end

  def serial
    serial_number unless recovered
  end

  before_save :set_paints
  def set_paints
    self.paint_id = nil if paint_id.present? && paint_name.blank? && paint_name != nil
    return true unless paint_name.present?
    self.paint_name = paint_name[0] if paint_name.kind_of?(Array)
    return true if Color.friendly_find(paint_name).present?
    paint = Paint.friendly_find(paint_name)
    paint = Paint.create(name: paint_name) unless paint.present?
    self.paint_id = paint.id
  end

  def paint_description
    paint.name.titleize if paint.present?
  end

  def frame_colors
    [
      primary_frame_color && primary_frame_color.name,
      secondary_frame_color && secondary_frame_color.name,
      tertiary_frame_color && tertiary_frame_color.name
    ].compact
  end

  def type # Small helper because we call this a lot
    cycle_type.name.downcase
  end

  def cgroup_array # list of cgroups so that we can arrange them
    return [] unless components.any?
    a = []
    components.each { |i| a << i.cgroup_id }
    a.uniq
  end

  def cache_photo
    if public_images.any?
      self.thumb_path = public_images.first.image_url(:small)
    end
  end

  def components_cache_string
    components.all.map.each do |c|
      [
        c.year,
        (c.manufacturer && c.manufacturer.name),
        c.component_type
      ] if c.ctype.present? && c.ctype.name.present?
    end
  end

  def cache_stolen_attributes
    csr = find_current_stolen_record
    self.attributes = {
      current_stolen_record_id: csr && csr.id,
      all_description: [description, csr && csr.theft_description].reject(&:blank?).join(' '),
      stolen_lat: csr && csr.latitude,
      stolen_long: csr && csr.longitude
    }
  end

  before_save :cache_bike
  def cache_bike
    cache_stolen_attributes
    cache_photo
    self.cached_data = [
      mnfg_name,
      (propulsion_type.name == 'Foot pedal' ? nil : propulsion_type.name),
      year,
      (primary_frame_color && primary_frame_color.name),
      (secondary_frame_color && secondary_frame_color.name),
      (tertiary_frame_color && tertiary_frame_color.name),
      (frame_material && frame_material.name),
      frame_size,
      frame_model,
      (rear_wheel_size && "#{rear_wheel_size.name} wheel"),
      (front_wheel_size && front_wheel_size != rear_wheel_size ? "#{front_wheel_size.name} wheel" : nil),
      additional_registration,
      (type == 'bike' ? nil : type),
      components_cache_string
    ].flatten.reject(&:blank?).join(' ')
  end
end
