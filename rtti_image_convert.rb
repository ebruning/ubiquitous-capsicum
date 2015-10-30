#!/usr/bin/env ruby

require 'rest_client'
require 'nokogiri'
require "base64"
require 'optparse'

def delete_folder(base_folder)
  puts "cleaning up evrs folder"
  FileUtils.rm_rf(Dir.glob("#{base_folder}/evrs/*"))
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

image_folders.each do |file|
  puts "sending  => #{file}"

  new_filename = File.basename(file).downcase.chomp(".jpg")
  new_filename = File.join(base_folder, "evrs/#{new_filename}.tif")

  response = RestClient.post("http://#{address}/mobilesdk/api/#{project}",
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
      puts "saving   => #{new_filename}"
      f.write(Base64.decode64(link.content))
    end
  end
end
