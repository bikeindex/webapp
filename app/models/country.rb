class Country < ActiveRecord::Base
  validates_presence_of :name
  validates_uniqueness_of :name, :iso

  has_many :stolen_records
  has_many :locations

  def self.name_translation(iso, locale: nil)
    I18n.t(iso, scope: :countries, locale: locale)
  end

  def self.select_options(locale: nil)
    pluck(:id, :iso).map { |id, iso| [name_translation(iso, locale: locale), id] }
  end

  def self.fuzzy_find(str)
    return nil unless str.present?
    fuzzy_iso_find(str) || where("lower(name) = ?", str.downcase.strip).first
  end

  def self.fuzzy_iso_find(str)
    str = "us" if str.match(/usa/i)
    str && where("lower(iso) = ?", str.downcase.strip).first
  end

  def self.united_states
    where(name: "United States", iso: "US").first_or_create
  end

  def self.valid_names
    StatesAndCountries.countries.map { |c| c[:name] }
  end
end
