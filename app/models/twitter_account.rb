class TwitterAccount < ActiveRecord::Base
  scope :active, -> { where(active: true) }
  scope :national, -> { active.where(national: true) }

  has_many :tweets, dependent: :destroy

  serialize :twitter_account_info
  attr_accessor :no_geocode

  geocoded_by :address
  after_validation :geocode, if: lambda { !no_geocode && address.present? && (latitude.blank? || address_changed?) }
  before_save :reverse_geocode, if: lambda { !no_geocode && latitude.present? && (state.blank? || state_changed?) }
  before_save :fetch_account_info

  reverse_geocoded_by :latitude, :longitude do |account, results|
    if (geo = results.first)
      account.country = geo.country
      account.city = geo.city
      account.state = geo.state_code
      account.neighborhood = geo.neighborhood
    end
  end

  def self.create_from_twitter_oauth(info)
    create(
      screen_name: info.dig("info", "nickname"),
      address: info.dig("info", "location"),
      consumer_key: ENV.fetch("TWITTER_CONSUMER_KEY"),
      consumer_secret: ENV.fetch("TWITTER_CONSUMER_SECRET"),
      user_token: info.dig("credentials", "token"),
      user_secret: info.dig("credentials", "secret"),
    )
  end

  def self.fuzzy_screen_name_find(name)
    return if name.blank?
    where("lower(screen_name) = ?", name.downcase.strip).first
  end

  def self.default_account
    where(default: true).first || national.first
  end

  def self.default_account_for_country(country)
    national.where(country: country).first || default_account
  end

  def twitter_account_url
    "https://twitter.com/#{screen_name}"
  end

  def twitter_link
    "<a href='#{twitter_account_url}'>@#{screen_name}</a>"
  end

  def fetch_account_info
    self.twitter_account_info ||= twitter_user.to_h
  end

  def twitter_user
    twitter_client.user(screen_name)
  end

  def twitter_client
    @twitter_client ||= Twitter::REST::Client.new do |config|
      config.consumer_key = consumer_key
      config.consumer_secret = consumer_secret
      config.access_token = user_token
      config.access_token_secret = user_secret
    end
  end

  def account_info_name
    return if twitter_account_info.blank?
    twitter_account_info[:name]
  end

  def account_info_image
    return if twitter_account_info.blank?
    twitter_account_info[:profile_image_url_https]
  end
end
