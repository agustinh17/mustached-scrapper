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
$project_name = 'nmx_normas_mexicanas'
DEBUG = 2

### command line options ###
opts = Trollop::options do
  opt :worker_amount, "Number of workers", :default => 5   # integer --worker-amount <i>, default to 5
  opt :max_retries, "Maximun number of retries", :default => 10 # integer --max-retries <i>, default 10
	opt :proxy_host, "HTTP Proxy host", :type => :string
	opt :proxy_port, "HTTP Proxy port", :type => :string
end

$max_retries = opts[:max_retries]
$worker_amount = opts[:worker_amount]
$proxy_host = opts[:proxy_host]
$proxy_port = opts[:proxy_port]
$dump_type = :initial_dump

beginning_time = Time.now
puts 'Comenzando Modificado...'

#create folder structure
create_initial_folder_structure

#collect norm keys
#cancelled ...
#... and current 
current_norm_keys = collect_current_norm_keys
cancelled_norm_keys = collect_cancelled_norms_keys

#process norms: download and parse original html, create folder structure,...
#...create document metadata, download pdf content and generate plain text version

#current ...
result, field_metadata = process_norms(current_norm_keys, :vigente)

#...and cancelled norms
result, field_metadata = process_norms(cancelled_norm_keys, :cancelled, result, field_metadata)

#write INFO.xml including metadata obtained from documents
create_info_xml result, field_metadata, 'initial_dump'

#create output_file
create_output_file result

#create COMPLETED file
`touch #{'./' + $project_name + '/intial_dump/COMPLETED'}`

puts "Fin. Tiempo transcurrido: #{(Time.now - beginning_time)} segundos"
puts 'Se procesaron correctamente ' + result[:success].length.to_s + ' documentos'
puts 'Hubo ' + result[:error].length.to_s + ' documentos que no pudieron ser procesados'
