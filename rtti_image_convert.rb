#!/usr/bin/env ruby

require 'rest_client'
require 'nokogiri'
require "base64"

base_folder = "/Users/ethan/Raw"

$image_folders = Dir.glob("#{base_folder}/**/*.jpg")

$image_folders.each do |file|
  puts "sending => #{file}"

  new_filename = File.basename(file)
  new_filename = File.join(File.dirname(file), "evrs/#{new_filename}.tif")

  response = RestClient.post('http://172.31.1.115/mobilesdk/api/color',
                                {
                                  :processImage => 'true',
                                  :imageResult => 'true',
                                  :accept => :json,
                                  :name_of_file_param => File.new(file)
                                }
                            )

  puts "response => #{response.code}"

  doc = Nokogiri::HTML(response.body)
  doc.xpath('//image').each do |link|
    File.open(new_filename, 'wb') do|f|
      puts "saving #{new_filename}"
      f.write(Base64.decode64(link.content))
    end
  end
end
