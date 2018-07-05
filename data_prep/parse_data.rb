require 'json'
require 'pry'

class ParseData
  def initialize(data, normalize_list, outfile, data_dir)
    @data = File.read(data_dir+"/"+data)
    @normalize_list = JSON.parse(File.read(normalize_list))
    @output = Array.new
    @outfile = outfile
    @link_list = Hash.new
    @data_dir = data_dir
  end

  # Generate link lists categorized by company/type
  def gen_link_lists
    @output.each do |doc|
      doc[:associated_documents].each do |link_type, links|
        links.each do |link|
          # Append company name if it is added already, otherwise don't
          if @link_list[link]
            @link_list[link][:associated_companies].push(doc[:name])
          else
            @link_list[link] = {link_type: link_type, associated_companies: [doc[:name]]}
          end
        end
      end
    end

    # Remove duplicates and print
    @link_list.each{|k, v| v[:associated_companies].uniq!}
    File.write("#{@data_dir}/linklist_#{@outfile}", JSON.pretty_generate(@link_list))
  end

  def parse
    split_data = @data.split("\n\n\n")
    split_data.each do |company|
      chash = Hash.new

      # Parse general fields about company
      chash[:name] = pull_field(company, "Name")
      chash[:associated_companies] = pull_field(company, "Name")
      chash[:office_city] = parse_arr_field(pull_field(company, "City"))
      chash[:office_country] = parse_arr_field(pull_field(company, "Country"))
      chash[:website] = pull_field(company, "Website")
      chash[:twitter] = pull_field(company, "Twitter")
      chash[:facebook] = pull_field(company, "Facebook")
      chash[:linkedin] = pull_field(company, "LinkedIn")
      chash[:github] = pull_field(company, "Github")
      chash[:document_type] = "Company"

      # Parse details about their work
      chash[:part_of_pipeline] = normalize(parse_arr_field(pull_field(company, "Part of political marketing pipeline")))
      chash[:products_services_category] = normalize(parse_arr_field(pull_field(company, "Products/Services")))
      chash[:customer_country] = parse_arr_field(pull_field(company, "Country of Customers", "Known Customers"))
      chash[:known_customers] = parse_arr_field(pull_field(company, "Known Customers", "Associated People"))
      chash[:associated_people] = parse_arr_field(pull_field(company, "Associated People", "Partner/Associated Companies"))
      chash[:affiliated_companies] = parse_arr_field(pull_field(company, "Partner/Associated Companies", "Data Sources"))
      chash[:data_sources] = normalize(parse_arr_field(pull_field(company, "Data Sources", "Advertising/Targeting Methods")))
      chash[:targeting_methods] = normalize(parse_arr_field(pull_field(company, "Advertising/Targeting Methods", "Associated Documents")))

      # Details that may require additional processing
      chash[:associated_documents] = split_url_types(parse_arr_field(pull_field(company, "Associated Documents", "Description/notes about work")), chash[:website])
      chash[:description] = pull_field(company, "Description/notes about work", "Legal Entities")
      chash[:legal_entities] = parse_arr_field(pull_field(company, "Legal Entities", "Searx Queries"))
      chash[:searx_queries] = pull_field(company, "Searx Queries")
      @output.push(chash)
    end

    File.write(@data_dir+"/"+@outfile, JSON.pretty_generate(@output))
  end

  # Normalize each item in array
  def normalize(data)
    if data
      return data.map do |item|
        item = @normalize_list[item] if @normalize_list[item]
        item
      end
    end
  end

  # Split into different types
  def split_url_types(associated_docs, url)
    url = url_clean(url) if url
  
    remote_pdf =  associated_docs.select{|i| (i.include?(".pptx")) || (i.include?("pdf") && i[0] != "/")}
    local_pdf =  associated_docs.select{|i| i.include?(".pdf") && i[0] == "/"}
    company_website =  associated_docs.select{|i| (i.include?(url) && !i.include?(".pdf")) if url}
    linkedin =  associated_docs.select{|i| i.include?("linkedin")}
    archive = associated_docs.select{|i| i.include?("archive.org") || i.include?("archive.is")}
    news = associated_docs-(remote_pdf+local_pdf+company_website+linkedin+archive)

    return {
      remote_pdf: remote_pdf,
      local_pdf: local_pdf,
      company_website: company_website,
      linkedin: linkedin,
      archive: archive,
      news: news
    }
  end

  # Clean url for checking
  def url_clean(url)
    url.gsub("https://", "").gsub("http://", "").gsub("www.", "")
  end

  # Parse a field that should go in an array
  def parse_arr_field(contents)
    if contents
      return contents.split(",").flatten.map{|i| i.strip.lstrip}
    end
  end

  # Pull field contents
  def pull_field(company, field, next_field=nil)
    # Get the next field
    if next_field
      raw = company.split("#{next_field}")[0].split("#{field}:")[1]
      return raw.gsub("\n\n", "<br />").gsub("\n", " ").strip.lstrip if raw
    elsif field.include?("Searx")
      found_field = company.split("#{field}:")[1]
      if found_field
        return found_field.strip.lstrip
      end
    else
      found_field = company.split("\n").select{|i| i.include?("#{field}:")}[0]
     
      # Process field found
      if found_field
        raw = found_field.split("#{field}: ")[1]
        return raw.strip.lstrip if raw
      end
    end
  end
end

outfile = "processed_companies.json"
data_dir = "data"
p = ParseData.new("raw_data4.txt", "remap_keys.json", outfile, data_dir)
p.parse
p.gen_link_lists
