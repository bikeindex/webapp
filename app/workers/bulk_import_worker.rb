require 'csv'

class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :bulk_import, :line_errors # Only necessary for testing

  def perform(bulk_import_id)
    @bulk_import = BulkImport.find(bulk_import_id)
    process_csv(@bulk_import.open_file)
    return false if @bulk_import.import_errors?
    @bulk_import.progress = "finished"
    return @bulk_import.save unless @line_errors.any?
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    @bulk_import.update_attribute :import_errors, (@bulk_import.import_errors || {}).merge("line" => @line_errors.compact)
  end

  def process_csv(file)
    @line_errors = @bulk_import.line_import_errors || [] # We always need line_import_errors
    return false if @bulk_import.finished? # If url fails to load, this will catch
    # Grab the first line of the csv (which is the header line) and transform it
    headers = convert_headers(file.readline)
    # Stream process the rest of the csv
    row_index = 1
    CSV.foreach(file, headers: headers) do |row|
      break false if @bulk_import.finished?
      row_index += 1
      next if row_index == 2 # Because we manually set the header
      bike = register_bike(row_to_b_param_hash(row.to_h))
      next if bike.id.present?
      # row_index is current line + 1, we want to offset count by 1 (people don't use line 0)
      @line_errors << [row_index, bike.cleaned_error_messages]
    end
  end

  def register_bike(b_param_hash)
    b_param = BParam.create(creator_id: creator_id,
                            params: b_param_hash,
                            origin: "bulk_import_worker")
    BikeCreator.new(b_param).create_bike
  end

  def row_to_b_param_hash(row)
    # Set a default color of black, since sometimes there aren't colors in imports
    color = row[:color].present? ? row[:color] : "Black"
    # Set default manufacture, since sometimes manufacture is blank
    manufacturer = row[:manufacturer].present? ? row[:manufacturer] : "Unknown"
    {
      bulk_import_id: @bulk_import.id,
      bike: {
        is_bulk: true,
        manufacturer_id: manufacturer,
        owner_email: row[:email],
        color: color,
        serial_number: rescue_blank_serial(row[:serial]),
        year: row[:year],
        frame_model: row[:model],
        description: row[:description],
        frame_size: row[:frame_size],
        send_email: @bulk_import.send_email,
        creation_organization_id: @bulk_import.organization_id
      },
      # Photo need to be an array - only include if photo has a value
      photos: row[:photo].present? ? [row[:photo]] : nil
    }
  end

  def rescue_blank_serial(serial)
    return "absent" unless serial.present?
    serial.strip!
    if ["n.?a", "none", "unkn?own"].any? { |m| serial.match(/\A#{m}\z/i).present? }
      "absent"
    else
      serial
    end
  end

  def creator_id
    # We want to use the organization auto user id if it exists
    @creator_id ||= @bulk_import.creator.id
  end

  def convert_headers(str)
    headers = str.split(",").map { |h| h.strip.gsub(/\s/, "_").downcase.to_sym }
    header_name_map.each do |value, replacements|
      next if headers.include?(value)
      replacements.each do |v|
        next unless headers.index(v).present?
        headers[headers.index(v)] = value
        break # Because we have found the header we're replacing, stop iterating
      end
    end
    validate_headers(headers)
    headers
  end

  private

  def validate_headers(attrs)
    valid_headers = (attrs & %i[manufacturer email serial]).count == 3
    # Update the progress in here, since we're successfully processing the file right now
    return @bulk_import.update_attribute :progress, "ongoing" if valid_headers
    @bulk_import.add_file_error("Invalid CSV Headers: #{attrs}")
  end

  def header_name_map
    {
      manufacturer: %i[manufacturer_id brand vendor],
      model: %i[frame_model],
      year: %i[frame_year],
      serial: %i[serial_number],
      photo: %i[photo_url],
      email: %i[customer_email]
    }
  end
end
