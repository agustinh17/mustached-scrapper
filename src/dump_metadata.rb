# coding: utf-8
require 'yaml'
require 'thread'
require 'date'


def create_info_xml document_ok, field_metadata, dump_type
	builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|

	xml.config {

		xml.bulk_api_version_ '1.0'
		xml.delivery_type_ dump_type
		xml.project_name_ $project_name
		xml.source_ 'Catálogo de Normas Mexicanas (NMX)'
		xml.source_url_ 'http://www.economia-nmx.gob.mx/normasmx/index.nmx'
		xml.documents_ document_ok[:success].length.to_s
		xml.source_id_ '6404'

		xml.fields {
		  xml.field('name' => 'key', 'type' => 'string') #clave de la norma
		  xml.field('name' => 'title', 'type' => 'string')
		  xml.field('name' => 'publication_date', 'type' => 'date')
		  xml.field('name' => 'type', 'type' => 'list'){
				field_metadata[:type].each_with_index do |type, index|
					xml.valid_value('value_id' => (index+1).to_s.rjust(2, '0'), 'value_description' => type )
				end
			}
		  xml.field('name' => 'cancellation_date', 'type' => 'date')
		  xml.field('name' => 'product', 'type' => 'dependent_list', 'depends_on' => 'economic_activity'){
			field_metadata[:product].each_with_index do |product, index|
				xml.valid_value('valid_id'  => (index+1).to_s.rjust(2, '0'), 
						'value_description' => product[0],
						'parent_field_id' => 
						(field_metadata[:economic_activity].index(product[1]) + 1).to_s.rjust(2, '0')
						)
			end
		}
		  xml.field('name' => 'economic_activity', 'type' => 'list'){
				field_metadata[:economic_activity].each_with_index do |economic_activity, index|
					xml.valid_value('valid_id' => (index+1).to_s.rjust(2, '0'), 'value_description' => economic_activity)
				end
			}
		  xml.field('name' => 'ctnn', 'type' => 'list'){
				field_metadata[:ctnn].each_with_index do |ctnn, index|
					xml.valid_value('value_id' => (index+1).to_s.rjust(2, '0'), 'value_description' => ctnn)				
				end
			}
		  xml.field('name' => 'onn', 'type' => 'list'){
				field_metadata[:onn].each_with_index do |onn, index|
					xml.valid_value('valid_id' => (index+1).to_s.rjust(2, '0'), 'value_description' => onn)
				end
			}
		  xml.field('name' => 'current', 'type' => 'list') do
				xml.valid_value('value_id' => 'current', 'value_description' => 'Norma vigente')
				xml.valid_value('value_id' => 'cancelled', 'value_description' => 'Norma cancelada')
			end
		}
	}
	end
	if $dump_type == :initial_dump
		File.open('./' + $project_name + '/initial_dump/INFO.xml', 'w') do |f|  
			f.puts builder.to_xml  
		end
	else
		File.open('./' + $project_name + '/updates/'+ Date.today.strftime("%Y-%m-%d") + '/INFO.xml', 'w') do |f|  
			f.puts builder.to_xml  
		end			
	end  
	
end

def create_initial_folder_structure
	puts 'Create initial folder structure...' if DEBUG == 1
	### create folder structure ###
	Dir.mkdir($project_name) unless File.exists?($project_name)
	if $dump_type == :initial_dump
		Dir.mkdir($project_name + "/initial_dump") unless File.exists?($project_name + "/initial_dump")
		Dir.mkdir($project_name + '/initial_dump/documents') unless File.exists?($project_name + '/initial_dump/documents')
		puts 'OK' if DEBUG ==1
	else
		updates_dir = $project_name + "/updates"
		date_dir = updates_dir + "/" + Date.today.strftime("%Y-%m-%d")
		documents_dir = date_dir + '/documents'

		[updates_dir, date_dir, documents_dir].each do |dir| 
			Dir.mkdir(dir) unless File.exists?(dir)
		end
	end
end

def create_output_file result
	File.open("output_" + Time.now.utc.iso8601.gsub(/\W/, '') + '.yml', "w") do |f|
		f.write result[:success].to_yaml
	end
	File.open("errors.yml", "w") do |f|
		f.write result[:error].to_yaml
	end
end

def read_input_file
	b = YAML.load File.open($continuation_filename, 'r')
end
