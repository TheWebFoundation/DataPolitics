require 'json'
require 'pry'
require 'curb'

class ProcessCompanies
  def initialize(data_dir, companies, api_key)
    @data_dir = data_dir
    @companies = JSON.parse(File.read(data_dir+"/"+companies))
    @api_key = api_key
    @output = Array.new
  end

  # Loop through the companies
  def process
    @companies.each do |company|
      company[:oc_entities] = get_opencorporates(company["legal_entities"]) if company["legal_entities"]
      @output.push(company)
    end

    File.write("../processed_data/companies/final_companies.json", JSON.pretty_generate(@output))
  end

  # Get the open corporates data
  def get_opencorporates(links)
    oc_data = Array.new

    links.each do |link|
      oc_data += query_oc_api(link)
    end

    return gen_link_names(oc_data)
  end

  # Generate the names for the opencorporates data
  def gen_link_names(oc_data)
    return oc_data.map{|c| [c["opencorporates_url"], "#{c["name"]} (#{c["jurisdiction_code"]})"]}
  end

  # Query the opencorporates API for different link types
  def query_oc_api(link)
    if link.include?("api")
      c = Curl::Easy.new(link+"?api_token=#{@api_key}")
      c.perform
      return JSON.parse(c.body_str)["results"]["companies"].map{|c| c["company"]}
    else
      api_link = link.gsub("https://opencorporates.com", "https://api.opencorporates.com")
      c = Curl::Easy.new(api_link+"?api_token=#{@api_key}")
      c.perform
      return [JSON.parse(c.body_str)["results"]["company"]]
    end
  end
end

data_dir = "data"
companies = "processed_companies.json"
oc_api_key = File.read("../../oc_api_key.txt").strip.lstrip

p = ProcessCompanies.new(data_dir, companies, oc_api_key)
p.process
