#!/usr/bin/env ruby

#require 'rest_client'
require 'unirest'
require 'nokogiri'
require 'base64'
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

def file_status(title, message)
  puts "#{Tty.white}#{title}#{Tty.reset} => #{Tty.blue}#{message}#{Tty.reset}"
end

def delete_folder(base_folder)
  puts "#{Tty.white}cleaning up evrs folder#{Tty.reset}"
  FileUtils.rm_rf(Dir.glob("#{base_folder}/evrs/*"))
end

def write_image_from_xml(doc, new_filename)
  doc.xpath('//image').each do |link|
    File.open(new_filename, 'wb') do|f|
      file_status('saving', File.basename(new_filename))
      puts
      f.write(Base64.decode64(link.content))
    end
  end
end

def summary_message(base, image_count, failed_count, images)
  puts 'Summary'
  puts '-------------'
  puts "#{Tty.white}output folder: #{Tty.reset}#{base}/evrs/"
  puts "#{Tty.white}processed:     #{Tty.reset}#{image_count}"
  puts "#{Tty.red}failed:        #{Tty.reset}#{failed_count}"
  puts '-------------'

  return true if images.length > 0
  puts
  puts "#{Tty.red}failed images#{Tty.reset}\n"
  images.each do |file|
    puts "\t#{file}"
  end
end

options = {}
options_parsers = OptionParser.new do |opts|
  opts.on('-a ADDRESS', '--server ADDRESS', 'RTTI server') do |address|
    options[:address] = address
  end

  opts.on('-r', '--return-image', 'Return cleaned image to client') do
    options[:return_image] = true
    options[:clean_image] = true
  end

  opts.on('-c', '--clean-image', 'Run IP on server') do
    options[:clean_image] = true
  end

  opts.on('-p PROJECT', '--project PROJECT', 'KTM project to use') do |project|
    options[:project] = project
  end

  opts.on('-e EXT', '--extension EXT', 'Extension to import') do |extension|
    options[:extension] = extension
  end

  opts.on('-d DIRECTORY', '--directory DIRECTORY', 'Folder to scan') do |directory|
    unless Dir.exist?(directory)
      fail ArgumentError, "The #{directory} directory doesn't exist"
    end
    options[:directory] = directory
  end

  opts.on_tail("-h", "--help") do
    puts opts
    exit
  end
end

options_parsers.parse!
puts options.inspect

puts options[:return_image]
exit
base_folder = options[:directory]
address = options[:address]
project = options[:project]
extension = options[:extension]

if !Dir.exist?("#{base_folder}/evrs/")
  puts "#{Tty.white}creating evrs folder#{Tty.reset}"
  Dir.mkdir("#{base_folder}/evrs/")
else
  delete_folder(base_folder)
end

if extension.nil?
  fail ArgumentError, 'Need to pass a file extension to use'
end
image_folders = Dir.glob("#{base_folder}/**/*.#{extension}")

successful_count = 0
failed_count = 0
failed_images = Array[]

image_folders.each do |file|
  file_status('sending', File.basename(file))

  new_filename = File.join(base_folder, "evrs/#{File.basename(file).downcase
                                        .chomp(".#{extension}")}.tif")

  begin
    response = Unirest.post "http://#{address}/mobilesdk/api/#{project}",
                        headers:{ "Accept" => "application/json" },
                        parameters:{ :fieldNameHere => File.new(file), :processImage => 'true', :imageResult =>'true' }

    puts response.body
    exit
  rescue RestClient::ExceptionWithResponse => err
    error(err)
    failed_images.push(file)
    failed_count += 1
  end

  while response
    successful_count += 1
    file_status('response', response.code)
    write_image_from_xml(Nokogiri::HTML(response.body), new_filename)
    break
  end
end

summary_message(base_folder, successful_count, failed_count, failed_images)
