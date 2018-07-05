require 'curb'
require 'json'

Dir["../processed_data/companies/*"].each do |file|
  json = JSON.pretty_generate(JSON.parse(File.read(file)))
  c = Curl::Easy.new("http://localhost:3000/add_items")
  c.http_post(Curl::PostField.content("item_type", "DpCompanies"),
              Curl::PostField.content("index_name", "datapolitics"),
              Curl::PostField.content("items", json))
end

Dir["../processed_data/brochures/*"].each do |file|
  json = JSON.pretty_generate(JSON.parse(File.read(file)))
  c = Curl::Easy.new("http://localhost:3000/add_items")
  c.http_post(Curl::PostField.content("item_type", "DpDocument"),
              Curl::PostField.content("index_name", "datapolitics"),
              Curl::PostField.content("items", json))
end

Dir["../processed_data/news/*"].each do |file|
  json = JSON.pretty_generate(JSON.parse(File.read(file)))
  c = Curl::Easy.new("http://localhost:3000/add_items")
  c.http_post(Curl::PostField.content("item_type", "DpNews"),
              Curl::PostField.content("index_name", "datapolitics"),
              Curl::PostField.content("items", json))
end
