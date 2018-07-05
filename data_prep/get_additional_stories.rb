require 'json'
require 'pry'
require 'nokogiri'
require 'open-uri'
require "selenium-webdriver"

# Run Searx scraper as needed to get additional stories
class GetAdditionalStories
  def initialize(data_dir, link_list, companies)
    @data_dir = data_dir
    @link_list = JSON.parse(File.read(@data_dir+"/"+link_list))
    @companies = JSON.parse(File.read(@data_dir+"/"+companies))
    @outfile = companies
    @driver = Selenium::WebDriver.for :firefox
  end

  # Get the news stories
  def get_stories
    searx_urls = filter_for_searx_urls

    # Run searx on each URL
    searx_urls.each do |item|
      # Get first couple pages of results
      begin
        results = request_results(item[:searx])
        results += request_results(item[:searx]+"&pageno=2").to_a
      rescue
        
      end

      results.each do |result|
        # Check if it is added and if not add again
        if @link_list[result[:result_link]]
          @link_list[result[:result_link]]["associated_companies"].push(item[:company_name])
        else
          @link_list[result[:result_link]] = {"link_type" => "News", "associated_companies" => [item[:company_name]]}
        end
      end
    end

    # Remove duplicates and print
    @link_list.each{|k, v| v["associated_companies"].uniq!}
    File.write("#{@data_dir}/wsearx_linklist_#{@outfile}", JSON.pretty_generate(@link_list))
  end

  # Request and parse results page
  def request_results(url)
    # Get the list of results
    begin
      puts "Getting #{url}"
      @driver.navigate.to(url)
      sleep(5)
      html = Nokogiri::HTML(@driver.page_source)
      results = html.css(".result")

      # Parse the results and save
      parsed = results.map{|result| parse_result(result, url)} if !results.empty?
      
      # Return results
      puts "Got #{url}"
      return parsed

    # Handle too many requests
    rescue Exception => e
     
    end
  end
  

  # Parse the individual result
  def parse_result(result, search_link)
    # Download individual result
    link = result.css(".result_header").css("a")[0]['href']
    category = search_link.split("categories=").last.split("&language").first

    # Result hash
    return {
      result_title: result.css(".result_header").text,
      result_blurb: result.css(".result-content").text,
      result_link: link
    }
  end
  
  # Get the query URLs and companies
  def filter_for_searx_urls
    return @companies.select{|c| c["searx_queries"] && (c["searx_queries"] != "")}.map{|c| {company_name: c["name"], searx: c["searx_queries"]}}
  end
end

data_dir = "data"
link_list = "linklist_processed_companies.json"
company_list = "processed_companies.json"
g = GetAdditionalStories.new(data_dir, link_list, company_list)
g.get_stories
