#!/usr/bin/env ruby

require 'rest_client'
require 'nokogiri'
require "base64"
require 'optparse'

module Tty extend self
  def blue; bold 34; end
  def white; bold 39; end
  def red; bold 31; end
  def reset; escape 0; end
  def bold n; escape "1;#{n}" end
  def underline n; escape "4;#{n}" end
  def escape n; "\033[#{n}m" if STDOUT.tty? end
end

def error(warning)
  puts "#{Tty.red}ERROR#{Tty.reset}: #{warning}"
  puts
end

def delete_folder(base_folder)
  puts "cleaning up evrs folder"
  FileUtils.rm_rf(Dir.glob("#{base_folder}/evrs/*"))
end

def write_image_from_xml(doc, new_filename)
  doc.xpath('//image').each do |link|
    File.open(new_filename, 'wb') do|f|
      puts "#{Tty.white}saving   #{Tty.reset}=> #{Tty.blue}#{File.basename(new_filename)}"
      puts
      f.write(Base64.decode64(link.content))
    end
  end
end

def summary_message(base, image_count, failed_count, images)
  puts "Summary"
  puts "-------------"
  puts "#{Tty.white}output folder: #{Tty.reset}#{base}/evrs/"
  puts "#{Tty.white}processed:     #{Tty.reset}#{image_count}"
  puts "#{Tty.red}failed:        #{Tty.reset}#{failed_count}"
  puts "-------------"

  if (images.length > 0)
    puts
    puts "#{Tty.red}failed images#{Tty.reset}\n"
    images.each do |file|
      puts "\t#{file}"
    end
  end

end

options = {}
options_parsers = OptionParser.new do |opts|
  opts.on("-a ADDRESS") do |address|
    options[:address] = address
  end

  opts.on("-p PROJECT", "--project PROJECT") do |project|
    options[:project] = project
  end

  opts.on("-e EXT", "--extension EXT") do |extension|
    options[:extension] = extension
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
extension = options[:extension]

if !Dir.exists?("#{base_folder}/evrs/")
  puts "creating evrs folder"
  Dir.mkdir("#{base_folder}/evrs/")
else
  delete_folder (base_folder)
end

if extension.nil?
  raise ArgumentError, "Need to pass a file extension to use"
end

image_folders = Dir.glob("#{base_folder}/**/*.#{extension}")

successfulCount = 0
failedCount = 0
failed_images = Array[]

image_folders.each do |file|
  puts "#{Tty.white}sending  #{Tty.reset}=> #{Tty.blue}#{File.basename(file)}"

  new_filename = File.join(base_folder, "evrs/#{File.basename(file).downcase.chomp(".jpg")}.tif")

  begin
    response = RestClient.post("http://#{address}/mobilesdk/api/#{project}",
                                  {
                                    :processImage => 'true',
                                    :imageResult => 'true',
                                    :accept => :json,
                                    :name_of_file_param => File.new(file)
                                  }
                              )

  rescue RestClient::ExceptionWithResponse => err
    error(err)
    failed_images.push(file)
    failedCount += 1
  end

    if (response)
      successfulCount += 1
      puts "#{Tty.white}response #{Tty.reset}=> #{Tty.blue}#{response.code}"
      write_image_from_xml(Nokogiri::HTML(response.body), new_filename)
    end
end

summary_message(base_folder, successfulCount, failedCount, failed_images)
