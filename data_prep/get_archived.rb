require 'pry'
require 'json'

class GetArchived
  def initialize(archived_path, path)
    @archived_path = archived_path
    @json = JSON.parse(File.read(path))
  end

  # Archive the site
  def archive_all
    @json.each do |item|
      archive_if_not_there(item) if !item['doc_path'].include?(".pdf") && !item['doc_path'].include?(".pptx")
    end
  end

  # Archive if it doesn't exist
  def archive_if_not_there(item)
    ignore_links = File.read("failed.txt").split("\n")
    
    if !File.exist?(@archived_path+"/"+website_path(item)+".html") && !ignore_links.include?(item['doc_link'])
      puts "Archiving #{website_path(item)}"
      archive_website(item)
      sleep(180)
      if !File.exist?(@archived_path+"/"+website_path(item)+".html")
        puts "FAILED #{item['doc_link']}"
        File.open("failed.txt", "a") {|f| f.puts item['doc_link']}
        system("systemctl stop beanstalkd")
        system("systemctl start beanstalkd")
        pid = spawn("cd /home/user/WF/node-beanstalkd-web-archiver && npm run start-debian")
        Process.detach(pid)
        sleep(10)
      end
    end
  end

  # Website path
  def website_path(data)
    return data['doc_link'].gsub("http://", "").gsub("https://", "").gsub("/", "-").split("&")[0].split("Press Releases:")[0].gsub(" ", "")
  end

  # Download archived copy of html
  def archive_website(data)
    system("node ../../node-beanstalkd-web-archiver/cli.js #{data['doc_link']}")
  end
  
end

archived_path = "/home/user/WF/node-beanstalkd-web-archiver/tests"
path = "/home/user/WF/DataPolitics/processed_data/news/final_news.json"
#path = "/home/user/WF/DataPolitics/processed_data/brochures/final_brochures.json"

g = GetArchived.new(archived_path, path)
g.archive_all
