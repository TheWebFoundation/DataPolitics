To update the data, do the following-
1. Copy raw data from etherpad and paste into data/. Update the path in
parse_data.rb to this data.

2. Run: ruby parse_data.rb

3. Run: ruby get_additional_stories.rb

4. Run: ruby get_link_content.rb. The processed brochures and news data should
now be saved in the processed_data/ folder.

5. Run: ruby process_companies.rb. Make sure there is an opencorporates API key in
../../oc_api_key.json. The processed companies should now be saved in the
processed_data/ folder

6. Run: ruby get_archived.rb. Be sure
https://github.com/bnvk/node-beanstalkd-web-archiver is installed first. Copy
files in test/ to ../documents in this repository.

7. Run: ruby fix_attachments.rb. This fixes broken attachment links.
