class SerialNormalizer
  def self.unknown_and_absent_corrected(str = nil)
    str = str.to_s.strip
    # Return unknown if blank, '?' or 'absent' (legacy concern - 'unknown' used to be stored as 'absent')
    return "unknown" if str.blank? || str.gsub(/\s|\?/, "").blank? || str.downcase == "absent"
    return "made_without_serial" if str.downcase == "made_without_serial"
    if str[/(no)|(remember)/i].present?
      return "unknown" if str[/unkno/i].present?
      return "unknown" if str[/(do.?n.?t)|(not?).?k?no/i].present? # Don't know
      return "unknown" if str[/(do.?n.?t)|(not?).?remember/i].present? # Don't remember
    end
    str
  end

  def initialize(serial: nil, bike_id: nil)
    @serial = serial && serial.strip.upcase
    @bike_id = bike_id
  end

  def normalized
    return nil if @serial.blank? || %w[UNKNOWN MADE_WITHOUT_SERIAL].include?(@serial)
    normed = @serial.dup
    serial_substitutions.each do |key, value|
      normed.gsub!(/[#{key}]/, value)
      normed.gsub!(/[^\w]|[_]/, " ") # turn all non letter/numbers into spaces
    end
    normed.gsub(/^0+/, "").gsub(/\s+/, " ").strip # remove leading zeros and multiple spaces
  end

  def normalized_segments
    return [] if normalized.blank?
    normalized.split(" ").reject(&:empty?).uniq
  end

  def save_segments(bike_id)
    existing = NormalizedSerialSegment.where(bike_id: bike_id)
    existing.map(&:destroy) if existing.present?
    return false unless Bike.where(id: bike_id).present?
    normalized_segments.each do |seg|
      NormalizedSerialSegment.create(bike_id: bike_id, segment: seg)
    end
  end

  private

  def serial_substitutions
    {
      "|IL" => "1",
      "O" => "0",
      "S" => "5",
      "Z" => "2",
      "B" => "8",
    }
  end
end
