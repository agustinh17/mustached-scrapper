mustached-scrapper
==================

Multi-threaded Web Scraping comand-line ruby scripts aimed to obtain documents(norms) from http://www.economia-nmx.gob.mx/normasmx/index.nmx 

Initially built in a consulting project, I open sourced this version.

## INITIAL_DUMP
### Description:
Downloads the content of http://www.economia-nmx.gob.mx/normasmx/index.nmx and produces a folder structure containing norms grouped by release date. Includes an xml file specifying the metadata for the norm, the html source of each norm as well as the pdf and plain text version.

### Usage:
$ cd bin
$ chmod +x initial_dump.rb
$ ./initial_dump.rb [options]

### Options:
  --worker-amount, -w <i>:   Number of workers (default: 5)
    --max-retries, -m <i>:   Maximun number of retries (default: 10)
     --proxy-host, -p <s>:   HTTP Proxy host
     --proxy-port, -r <s>:   HTTP Proxy port
               --help, -h:   Show options available

## UPDATE
### Description:
Looks for changes produced since the last dump from http://www.economia-nmx.gob.mx/normasmx/index.nmx and produces a folder structure containing norms grouped by release date.
Uploads the results through FTP to the specified server.

### Usage:
$ cd bin
$ chmod +x update.rb
$ ./update.rb [options]

### Options:
  --continuation-filename, -c <s>:   Continuation filename (default: input.yml)
          --worker-amount, -w <i>:   Number of workers (default: 5)
            --max-retries, -m <i>:   Maximun number of retries (default: 10)
               --ftp-host, -f <s>:   FTP host
               --ftp-user, -t <s>:   FTP username
               --ftp-pass, -p <s>:   FTP password
             --proxy-host, -r <s>:   HTTP Proxy host
             --proxy-port, -o <s>:   HTTP Proxy port
                       --help, -h:   Show options available
