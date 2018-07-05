require 'open-uri'
require 'json'
require 'pry'
require 'metainspector'
require "selenium-webdriver"

class GetLinkContent
  def initialize(data_dir, link_list)
    @data_dir = data_dir
    @link_list = JSON.parse(File.read(@data_dir+"/"+link_list))
    @driver = Selenium::WebDriver.for :firefox
  end

  # Download all link contents
  def download_all_link_contents
    # Run all
    gen_news_story_dataset
    gen_brochure_website_dataset
    gen_brochures_from_pdfs

    # Save final datasets
    pdf_broch = JSON.parse(File.read(@data_dir+"/pdf_brochures.json"))
    web_broch = JSON.parse(File.read(@data_dir+"/website_brochures.json"))
    File.write("../processed_data/brochures/final_brochures.json", JSON.pretty_generate((pdf_broch+web_broch)))
    filter_news = filter_links(JSON.parse(File.read(@data_dir+"/news_stories.json")))
    File.write("../processed_data/news/final_news.json", JSON.pretty_generate(filter_news))
  end

  # Filter the links
  def filter_links(data)
    # Filter out links on the list
    to_filter = JSON.parse(File.read("filter_links.json"))
    filtered = data.select{|i| !to_filter.include?(i["doc_link"])}

    # Filter companies on the list
    filter_companies = ["enodo global", "targetsmart", "ngp van", "axiom strategies", "dspolitical", "revolution messaging"]
    return filtered.select{|i| !filter_companies.include?(i["associated_companies"][0].downcase)}
  end

  # Generate brochures from pdfs
  def gen_brochures_from_pdfs
    # Get lists of pdfs
    remote = filter_by_type("remote_pdf")
    local = filter_by_type("local_pdf")
    pdf_data = Array.new
    old_pdf = JSON.parse(File.read(@data_dir+"/pdf_brochures.json"))
    
    # Download pdfs
    remote.each do |pdf|
      path = pdf_path(pdf)
      if !File.exist?("../documents/#{path}")
        system("wget -O ../documents/#{path} #{pdf[0]}")
      end
    end

    # OCR all PDFs and gen
    (remote.merge(local)).each do |pdf|
      existing = get_old_news(pdf, old_pdf)
      # Resave existing pdf
      if existing
        pdf_data.push(existing.merge({document_type: "Document"}))
      else # Not there, regen
        pdf_hash = gen_pdf_brochure_hash(pdf)
        pdf_data.push(pdf_hash)
      end
    end

    File.write(@data_dir+"/pdf_brochures.json", JSON.pretty_generate(pdf_data))
  end

  # Generate a hash for the PDF brochure
  def gen_pdf_brochure_hash(pdf)
    doc_path = pdf_path(pdf)
    brochure_text = ocr_pdf("../documents/#{doc_path}")
    brochure_title = doc_path.gsub(".pdf", "").gsub("_", " ").gsub("-", " ")

    return { doc_path: doc_path,
             brochure_text: brochure_text,
             brochure_title: brochure_title,
             doc_link: pdf[0],
             document_type: "Document",
             associated_companies: pdf[1]["associated_companies"]
    }
  end

  # OCR the pdf
  def ocr_pdf(file)
    puts "OCRing #{file}"
    return %x[abbyyocr11 -c -if #{file} -f TextVersion10Defaults -tel -tet UTF8 -tcp Latin].gsub(/\xef\xbb\xbf/, "")
  end

  # Get pdf local path
  def pdf_path(pdf)
    return pdf[0].gsub("/pdf", ".pdf").split("/").last
  end

  # Generate brochures from websites
  def gen_brochure_website_dataset
    websites = filter_by_type("company_website").merge(filter_by_type("archive"))
    old_web = JSON.parse(File.read(@data_dir+"/website_brochures.json"))
    website_data = Array.new

    websites.each do |website|
      existing = get_old_news(website, old_web)
      # Resave existing site
      if existing
        archived_page = archive_website(existing)
        website_data.push(existing.merge({document_type: "Document", doc_path: archived_page}))
      else # Pull site again
        puts "Getting data for #{website[0]}"
        begin
          website_hash = gen_website_hash(website)
          website_data.push(website_hash)
        rescue
          puts "SOMETHING WENT WRONG"
        end
      end
    end

    File.write(@data_dir+"/website_brochures.json", JSON.pretty_generate(website_data))
  end

  # Download archived copy of html
  def archive_website(data)
    system("node ../../node-beanstalkd-web-archiver/cli.js #{data['doc_link']}")
    return data['doc_link'].gsub("http://", "").gsub("https://", "").gsub("/", "-")
  end

  # Generate the website hash
  def gen_website_hash(website)
    # Get title and text
    title = get_page_title(website[0])
    brochure_text = parse_news_story(website[0])[:article_text]

    # Extract differently if blank
    if brochure_text == ""
      @driver.navigate.to(website[0])
      sleep(2)
      html = Nokogiri::HTML(@driver.page_source)
      brochure_text = html.css("body").text
      puts "GOT WITH SELENIUM"
    end

    # Merge hash and generate
    return { brochure_title: title,
                     brochure_text: brochure_text,
                     doc_link: website[0],
                     web_address: website[0],
                     document_type: "Document",
                     associated_companies: website[1]["associated_companies"]
                   }
  end

  # Generate the news story dataset
  def gen_news_story_dataset
    news_stories = filter_by_type("news")
    old_news = JSON.parse(File.read(@data_dir+"/news_stories.json"))
    news_data = Array.new
    
    news_stories.each do |story|
      # Save existing story if there is one
      existing = get_old_news(story, old_news)

      # Resave existing story
      if existing
        archived_page = archive_website(existing)
        news_data.push(existing.merge({document_type: "News", doc_path: archived_page}))
      else # Add new story
        # Get story if possible
        parsed_story = parse_news_story(story[0])
        
        if parsed_story != "NOTNEWS"
          story_hash = gen_story_hash(story, parsed_story)
          news_data.push(story_hash)
        else # Not news change to a different type
          change_type(story)
        end
      end
    end

    File.write(@data_dir+"/news_stories.json", JSON.pretty_generate(news_data))
  end

  # Gen new hash of the story
  def gen_story_hash(story, parsed_story)
    title = get_page_title(story[0])
    puts "loaded #{story[0]}"

    # Add story to hash
    story_hash = parsed_story.merge({
                                      doc_link: story[0],
                                      story_title: title,
                                      document_type: "News",
                                      associated_companies: story[1]["associated_companies"]
                                    })
  end

  # Get the item from the previously saved JSON
  def get_old_news(story, old_news)
    if old_news.select{|i| i["doc_link"] == story[0]}
      return old_news.select{|i| i["doc_link"] == story[0]}[0]
    end
  end

  # Change to a not news type
  def change_type(story)
    @link_list[story[0]]["link_type"] = "NOTNEWS"
    puts "#{story[0]} IS NOT NEWS!"
  end

  # Get the title for a page
  def get_page_title(url)
    page = MetaInspector.new(url)
    return page.title
  end

  # Get a list by type
  def filter_by_type(type)
    @link_list.select{|k, v| v["link_type"].downcase == type}
  end
  
  # Parse news category
  def parse_news_story(link)
    begin
      article = JSON.parse(`python3 parse_newspaper.py #{link}`)
    rescue
      return "NOTNEWS"
    end
    return Hash[article.map{ |k, v| [k.to_sym, v] }]
  end
end

data_dir = "data"
link_list = "wsearx_linklist_processed_companies.json"
g = GetLinkContent.new(data_dir, link_list)
g.download_all_link_contents

