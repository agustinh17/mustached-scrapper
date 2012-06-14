# coding: utf-8
require 'date'


CURRENT = 			{:key => 'tr:nth-child(2) td.contenidoROJO',
								:title => 'tr:nth-child(3) td.contenidoROJO',
								:publication_date => 'tr:nth-child(5) td.contenidoROJO',
								:cancellation_date => 'tr:nth-child(100) td.contenidoROJO',
								:type => 'tr:nth-child(6) td.contenidoROJO',
								:economic_activity => 'tr:nth-child(8) td.contenidoROJO',
								:ctnn => 'tr:nth-child(9) td.contenidoROJO',
								:onn => 'tr:nth-child(10) td.contenidoROJO',
								:download_link => 'tr:nth-child(4) td.contenidoROJO a',
								:file_name => 'tr:nth-child(4) td.contenidoROJO a',
								:product => 'tr:nth-child(7) td.contenidoROJO',
								:current => 'Norma vigente'}

CANCELLED = 		{:key => 'tr:nth-child(2) td.contenidoROJO',
								:title => 'tr:nth-child(3) td.contenidoROJO',
								:publication_date => 'tr:nth-child(5) td.contenidoROJO',
								:cancellation_date => 'tr:nth-child(6) td.contenidoROJO',
								:type => 'tr:nth-child(100) td.contenidoROJO',
								:economic_activity => 'tr:nth-child(8) td.contenidoROJO',
								:ctnn => 'tr:nth-child(9) td.contenidoROJO',
								:onn => 'tr:nth-child(10) td.contenidoROJO',
								:download_link => 'tr:nth-child(4) td.contenidoROJO a',
								:file_name => 'tr:nth-child(4) td.contenidoROJO a',
								:product => 'tr:nth-child(7) td.contenidoROJO',
								:current => 'Norma cancelada'}

class Document
	attr_accessor :key, :title, :publication_date, :cancelation_date, :type, :product, :economic_activity,
								 :ctnn, :onn, :current, :file_name, :download_link

	def initialize(html_source)
			puts 'Parseando documento...'  if DEBUG == 1
			begin
				doc = Nokogiri::HTML(html_source)
								
				css_selectors = doc.css('td font').first.text == 'Normas Mexicanas Vigentes' ? CURRENT : CANCELLED

				@key = doc.css(css_selectors[:key]).text
				@title = doc.css(css_selectors[:title]).text.chars.select{|i| i.valid_encoding?}.join
				@publication_date = Date.strptime(doc.css(css_selectors[:publication_date]).text, '%d/%m/%Y').strftime("%Y-%m-%d")
				@cancellation_date = Date.strptime(doc.css(css_selectors[:cancellation_date]).text, '%d/%m/%Y').strftime("%Y-%m-%d") if doc.at_css(css_selectors[:cancellation_date])
				@type = doc.css(css_selectors[:type]).text if doc.at_css(css_selectors[:type])
				@product = products_to_txt(doc.css(css_selectors[:product]))
				@economic_activity = doc.css(css_selectors[:economic_activity]).text.chars.select{|i| i.valid_encoding?}.join
				@ctnn = doc.css(css_selectors[:ctnn]).text.encode('UTF-8', :invalid => :replace, :replace => '').encode('UTF-8').chars.select{|i| i.valid_encoding?}.join

				@onn = doc.css(css_selectors[:onn]).text.encode('UTF-8', :invalid => :replace, :replace => '').encode('UTF-8').chars.select{|i| i.valid_encoding?}.join
				@current = css_selectors[:current]
				@download_link = doc.css(css_selectors[:download_link]).first['href']
				@file_name = doc.css(css_selectors[:file_name]).first.text

				puts 'OK' if DEBUG == 1
		rescue Exception => e 
			puts 'Se produjo un error al parsear el documento ' + @key if DEBUG == 1
		end

	end

	def products_to_txt txt_ng
		txt_comma = txt_ng.inner_html.gsub('<br><br>', ', ')
		txt_return = txt_comma.gsub('<br>', '')
	end

	def date_dir_name
		if $dump_type == :initial_dump 
			$project_name + '/initial_dump/documents/' + @publication_date
		else
			$project_name + '/updates/' + Date.today.strftime("%Y-%m-%d") + '/documents/' + @publication_date 
		end
	end

	def document_dir_name
		date_dir_name + '/' + @key.gsub('-', '').gsub('/', '')
	end

	def document_contents_dir_name
		document_dir_name + '/contents'
	end

	def document_attachments_dir_name
		document_dir_name + '/attachments'
	end

	def pdf_location
		document_contents_dir_name + '/' + @key.gsub('-', '').gsub('/', '') + '.pdf' 		
	end

	def txt_location
		document_contents_dir_name + '/' + @key.gsub('-', '').gsub('/', '') + '.txt'
	end

	def html_location
		document_contents_dir_name + '/' + @key.gsub('-', '').gsub('/', '') + '.html'
	end

	def xml_location
		document_dir_name + '/' + 'METADATA-' + @key.gsub('-', '').gsub('/', '') + '.xml'
	end

	def create_folder_structure
		Dir.mkdir(date_dir_name) unless File.exists?(date_dir_name)
		Dir.mkdir(document_dir_name) unless File.exists?(document_dir_name)
		Dir.mkdir(document_contents_dir_name) unless File.exists?(document_contents_dir_name)
		Dir.mkdir(document_attachments_dir_name) unless File.exists?(document_attachments_dir_name)
	end

	def persist_metadata_xml
		builder = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
			xml.document{
				xml.key @key
				xml.title @title
				xml.publication_date @publication_date
				xml.cancelation_date @cancellation_date if !@cancellation_date.nil?				
				xml.type @type
				xml.product @product
				xml.economic_activity @economic_activity
				xml.ctnn @ctnn
				xml.onn @onn
				xml.current_ @current
			}
		end

		File.open(xml_location, 'w') do |f|  
			f.puts builder.to_xml  
		end
	end
end

