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
DEBUG = 2

### command line options ###
opts = Trollop::options do
  opt :continuation_filename, "Continuation filename", :type => :string, :default => 'input.yml' # string --continuation-filename <filename>, default 'output.yml' 
  opt :worker_amount, "Number of workers", :default => 5   # integer --worker-amount <i>, default to 5
  opt :max_retries, "Maximun number of retries", :default => 10 # integer --max-retries <i>, default 10
	opt :ftp_host, "FTP host", :type => :string
	opt :ftp_user, "FTP username", :type => :string
	opt :ftp_pass, "FTP password", :type => :string
	opt :proxy_host, "HTTP Proxy host", :type => :string
	opt :proxy_port, "HTTP Proxy port", :type => :string
end

### golbal variable initialization ###
$project_name = 'nmx_normas_mexicanas'
$max_retries = opts[:max_retries]
$worker_amount = opts[:worker_amount]
$continuation_filename = opts[:continuation_filename]
$dump_type = :update
$ftp_host = opts[:ftp_host]
$ftp_user = opts[:ftp_user]
$ftp_pass = opts[:ftp_pass]
$proxy_host = opts[:proxy_host]
$proxy_port = opts[:proxy_port]

### comenzando ###
beginning_time = Time.now
puts 'Comenzando...'

### read continuation filename to obtain last dump results ###
last_dump_result = read_input_file

create_initial_folder_structure

cancelled_norm_keys = collect_cancelled_norms_keys

current_norm_keys = collect_current_norm_keys

### select wich norms will be procesed based on last dump results and status ###
filtered_current_norm_keys = current_norm_keys.select {|current_norm| not last_dump_result.has_key?(current_norm[0])} 

filtered_cancelled_norm_keys = cancelled_norm_keys.select{|cancelled_norm| last_dump_result[cancelled_norm[0]][:type]==:vigente unless not last_dump_result.has_key?(cancelled_norm[0])}

puts 'filtered_cancelled_norm_keys size = ' + filtered_cancelled_norm_keys.length.to_s if DEBUG == 1

puts 'filtered_current_norm_keys size = ' + filtered_current_norm_keys.length.to_s if DEBUG == 1

result, field_metadata = process_norms(filtered_current_norm_keys, :vigente)

result, field_metadata = process_norms(filtered_cancelled_norm_keys, :cancelled, result, field_metadata)

create_info_xml result, field_metadata, 'update'

create_output_file result

### upload result through FTP ###
`lftp -c "open -u #{$ftp_user},#{$ftp_pass} #{$ftp_host}; mirror -R ./nmx_normas_mexicanas/updates/ nmx_normas_mexicanas/"`

#create COMPLETED file
`touch #{'./' + $project_name + '/updates/'+ Date.today.strftime("%Y-%m-%d") + '/COMPLETED'}`

puts "Fin. Tiempo transcurrido: #{(Time.now - beginning_time)} segundos"
puts 'Se procesaron correctamente ' + result[:success].length.to_s + ' documentos'
puts 'Hubo ' + result[:error].length.to_s + ' documentos que no pudieron ser procesados'
