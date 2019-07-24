# We really should obfuscate the filename, for this and bulk imports
class ExportUploader < ApplicationUploader
  def store_dir
    "#{base_store_dir}exports/#{model.id}"
  end

  def base_store_dir
    "uploads/"
  end

  def extension_white_list
    %w(csv tsv xls xlsx)
  end
end
