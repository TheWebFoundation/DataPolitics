require 'json'
require 'pry'

class FixAttachments
  def initialize(file, attachment_field, prefix)
    @file_name = file
    @file = JSON.parse(File.read(file))
    @doc_path = attachment_field
    @output = Array.new
    @prefix = prefix
  end

  # Fix the attachment names to point to files that are there
  def fix_attachment_names
    @file.each do |item|
      attachment = item[@doc_path]

      # Clear if attachment doesn't exist or add suffix if needed
      if !doc_exists?(attachment)
        if doc_exists?(attachment+".html")
          item[@doc_path] = attachment+".html"
          attachment += ".html"
        else
          item[@doc_path] = ""
        end
      end

      # Fix spaces in name
      if attachment.include?("%")
        new_name = attachment.gsub("%20", "_").gsub("%3A", "_").gsub("%7C", "_")
        move_file(attachment, new_name)
        item[@doc_path] = new_name
      end

      @output.push(item)
    end
    write_output
  end

  # Write the output
  def write_output
    File.write(@file_name, JSON.pretty_generate(@output))
  end

  # Move file to a different file
  def move_file(attachment, new_name)
    system("cp #{@prefix+attachment} #{@prefix+new_name}")
  end
  
  # Check if attachment exists
  def doc_exists?(attachment)
    return File.exist?(@prefix+attachment)
  end
end

brochures_path = "../processed_data/brochures/final_brochures.json"
path_prefix = "../documents/"
f = FixAttachments.new(brochures_path, "doc_path", path_prefix)
f.fix_attachment_names


news_path = "../processed_data/news/final_news.json"
f = FixAttachments.new(news_path, "doc_path", path_prefix)
f.fix_attachment_names
