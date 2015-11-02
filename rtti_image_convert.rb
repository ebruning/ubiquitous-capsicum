#!/usr/bin/env ruby

require 'rest_client'
require 'nokogiri'
require "base64"
require 'optparse'

def delete_folder(base_folder)
  puts "cleaning up evrs folder"
  FileUtils.rm_rf(Dir.glob("#{base_folder}/evrs/*"))
end

def write_image_from_xml(doc, new_filename)
  doc.xpath('//image').each do |link|
    File.open(new_filename, 'wb') do|f|
      puts "saving   => #{File.basename(new_filename)}"
      puts
      f.write(Base64.decode64(link.content))
    end
  end
end

def summary_message(base, image_count, image_total)
  puts "output folder #{base}/evrs/"
  puts "procced #{image_count}/#{image_total}"
end

options = {}
options_parsers = OptionParser.new do |opts|
  opts.on("-a ADDRESS") do |address|
    options[:address] = address
  end

  opts.on("-p PROJECT", "--project PROJECT") do |project|
    options[:project] = project
  end

  opts.on("-d DIRECTORY") do |directory|
    unless Dir.exists?(directory)
      raise ArgumentError, "The #{directory} directory doesn't exist"
    end
    options[:directory] = directory
  end
end

options_parsers.parse!

base_folder = options[:directory]
address = options[:address]
project = options[:project]

if !Dir.exists?("#{base_folder}/evrs/")
  puts "creating evrs folder"
  Dir.mkdir("#{base_folder}/evrs/")
else
  delete_folder (base_folder)
end

image_folders = Dir.glob("#{base_folder}/**/*.jpg")

count = 0

image_folders.each do |file|
  puts "sending  => #{File.basename(file)}"
  count += 1

  new_filename = File.join(base_folder, "evrs/#{File.basename(file).downcase.chomp(".jpg")}.tif")

  response = RestClient.post("http://#{address}/mobilesdk/api/#{project}",
                                {
                                  :processImage => 'true',
                                  :imageResult => 'true',
                                  :accept => :json,
                                  :name_of_file_param => File.new(file)
                                }
                            )

  puts "response => #{response.code}"

  write_image_from_xml(Nokogiri::HTML(response.body), new_filename)

end

summary_message(base_folder, count, image_folders.length)
