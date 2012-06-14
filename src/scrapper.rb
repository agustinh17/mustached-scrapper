# coding: utf-8
require 'thread'


def get_cache_map
	if $cache_map.nil?
		$cache_map = Hash.new
		path_normas = %x(find -maxdepth 6 -mindepth 6).split("\n")
		path_normas.each do |path_norma|
			$cache_map[path_norma.split('/').last] = path_norma
		end
	end
	$cache_map
end


def init_agent_and_fill_index_form estado = nil 
	agent = Mechanize.new do |a|
		a.set_proxy($proxy_host,$proxy_port)
		a.user_agent_alias = "Windows IE 6"
	end
	page = agent.get("http://www.economia-nmx.gob.mx/normasmx/index.nmx")

	form = page.form_with(:action => 'consulta.nmx')
	if estado == :vigente
		form.checkbox_with('clave').check
	else
		form.radiobuttons[0].checked=false
		form.radiobuttons[1].checked=true
		form.checkbox_with('clave').check
	end
	page = form.submit
	return page, agent
end

def collect_current_norm_keys
	norm_keys = Array.new
	page, agent = init_agent_and_fill_index_form :vigente
	doc = Nokogiri::HTML(page.body)

	doc.css('select option').each do |node|
		norm_keys << [node['value'].strip,0] unless (node['value'] == '0' or norm_keys.include?(node['value']))
	end
	puts 'collect_current_norm_keys'
	return norm_keys	
end


def collect_cancelled_norms_keys
	norm_keys = Array.new
	page, agent = init_agent_and_fill_index_form :cancelada
	doc = Nokogiri::HTML(page.body)

	doc.css('select option').each do |node|
		norm_keys << [node['value'].strip,0] unless (node['value'] == '0' or norm_keys.include?(node['value']))
	end
	puts 'collect_cancelled_norm_keys'
	return norm_keys	
end

def download_html(key, type)
	map = get_cache_map
	flatten_key = key.gsub('-', '').gsub('/', '')
	if map.has_key?(flatten_key)
		page = ''
		f = File.open(map[flatten_key] + '/contents/' + flatten_key + '.html' , 'r')
		f.each_line do |line|
		  page += line
		end 
		return page
	else
		puts 'Obteniendo el codigo html...url=' 'http://www.economia-nmx.gob.mx/normasmx/detallenorma.nmx?clave=' + key if DEBUG == 1
		page, agent = init_agent_and_fill_index_form type
		page = agent.get ('http://www.economia-nmx.gob.mx/normasmx/detallenorma.nmx?clave=' + key)
	end
	return page.body
end

def download_pdf (destination, download_link)
	return if destination.nil? or download_link.nil? or download_link == 'http://200.77.231.100/work/normas/nmx/2000/seleccione.pdf'
	if File.exists?('./cache/' + destination)
		return `cp ./cache/#{destination} #{destination}`
	end
	puts 'Descargando adjunto...' if DEBUG == 1
	agent = Mechanize.new do |a|
		a.set_proxy($proxy_host,$proxy_port)
		a.user_agent_alias = "Windows IE 6"
	end
	agent.pluggable_parser.default = Mechanize::Download
	begin
		agent.get(download_link).save(destination)
		puts 'OK' if DEBUG == 1
	rescue Mechanize::ResponseCodeError
		puts 'Error al descargar ' + download_link  if DEBUG == 1
	end
end

def create_document(key, type)
	html_source = download_html(key, type)
	new_document = Document.new html_source
	return new_document, html_source
end

def persist_html location, content
	return if location.nil? or content.nil?
	File.open( location, 'w') do |f|  
		f.puts content
	end	
end

def create_txt_from_pdf source, destination
	return unless File.exists? (source)
	reader = PDF::Reader.new(source)
	File.open( destination, 'w:utf-8') do |f|  
		reader.pages.each do |page|
			f.puts page.text
		end
	end
end

def update_field_metadata(document, field_metadata)
	field_metadata[:type] << document.type unless field_metadata[:type].include? document.type
	field_metadata[:economic_activity] << document.economic_activity unless field_metadata[:economic_activity].include? document.economic_activity 
	field_metadata[:ctnn] << document.ctnn unless field_metadata[:ctnn].include? document.ctnn 
	field_metadata[:onn] << document.onn unless field_metadata[:onn].include? document.onn
	field_metadata[:product]  << [document.product, document.economic_activity] unless 
	field_metadata[:product].include? [document.product, document.economic_activity]
	return if document.product.nil? 
	if document.product.include? ","
		products = document.product.split(', ')

		products.each do |prod| 
			field_metadata[:product] << [prod, document.economic_activity] unless 
					field_metadata[:product].include? [prod, document.economic_activity]  
		end
	end
end

def process_norm norm_key, type, result = nil, field_metadata = nil, errors, mutex, total_normas, wq
		begin
		puts 'procesar norma ' + norm_key[0] if DEBUG == 1
		document, html = create_document(norm_key[0], type)
		puts 'create_document OK'  if DEBUG == 1
		document.create_folder_structure
		puts 'create_folder_structure OK'  if DEBUG == 1
		persist_html document.html_location, html
		puts 'persist_html OK' if DEBUG == 1

		document.persist_metadata_xml 
		puts 'persist_metadata_xml OK' if DEBUG == 1

  	mutex.synchronize do
			update_field_metadata(document, field_metadata)
			puts 'update_field_metadata OK' if DEBUG == 1

			result[:success][norm_key[0]] = {:type => type}
		end

		puts 'Norma ' + type.to_s + ' ' + norm_key[0] + '... OK . ' +result[:success].length.to_s + ' / ' + total_normas.to_s

	rescue
		puts 'Norma ' + type.to_s + ' ' + norm_key[0] + '...Error. Reintento ' +norm_key[1].to_s + ' Hubieron ' + errors.length.to_s + ' Errores'
		if norm_key[1] < $max_retries
			wq.enqueue_b([norm_key[0],norm_key[1]+1]) { |norm_key_modified| process_norm norm_key_modified, type, result, field_metadata, errors, mutex, total_normas, wq }
			sleep(60)
		else
			errors << [norm_key[0],10]
		end		
	end
	begin
		download_pdf document.pdf_location, document.download_link
		create_txt_from_pdf document.pdf_location, document.txt_location
	rescue
	end
end

def process_norms norm_keys, type, result = nil, field_metadata = nil
	if result.nil?
		result = Hash.new
		result[:success] = Hash.new
		result[:error] = Hash.new
	end
	if field_metadata.nil?
		field_metadata = Hash.new
		field_metadata[:type] = Array.new
		field_metadata[:economic_activity] = Array.new
		field_metadata[:ctnn] = Array.new
		field_metadata[:onn] = Array.new
		field_metadata[:product] = Array.new
	end
	errors = Queue.new
	mutex = Mutex.new
	total_normas = norm_keys.size
	wq = WorkQueue.new $worker_amount

	norm_keys.each do |norm_key|
		wq.enqueue_b do
			process_norm norm_key, type, result, field_metadata, errors, mutex, total_normas, wq
		end
	end
	wq.join
	
	return result, field_metadata
end
