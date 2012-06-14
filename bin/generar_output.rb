#!/usr/bin/env ruby
# coding: utf-8
require "rubygems"
require "bundler/setup"
Bundler.require(:default)

require 'open-uri'
require 'net/https'
require '../src/scrapper'
require '../src/document'
require '../src/dump_metadata'


### constants ###
$worker_amount = 5
$project_name = 'nmx_normas_mexicanas'
$max_retries = 10
$proxy_host = '202.29.242.123'
$proxy_port = '3128'
DEBUG = 1

beginning_time = Time.now
puts 'Comenzando...' if DEBUG == 1

cancelled_norm_keys = collect_cancelled_norms_keys
puts 'cancelled norms size = ' + cancelled_norm_keys.length.to_s

current_norm_keys = collect_current_norm_keys
puts 'current norms size = ' + current_norm_keys.length.to_s

result = Hash.new
result[:success] = Hash.new
result[:error] = Hash.new

cancelled_norm_keys.each do |norm_key|
	result[:success][norm_key[0]] = {:type => :cancelled}
end
current_norm_keys.each do |norm_key|
	result[:success][norm_key[0]] = {:type => :vigente}
end

#create output_file
create_output_file result

puts "Fin. Tiempo transcurrido: #{(Time.now - beginning_time)} segundos"
puts 'Se procesaron correctamente ' + result[:success].length.to_s + ' documentos'
puts 'Hubo ' + result[:error].length.to_s + ' documentos que no pudieron ser procesados'
