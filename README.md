# SiamCrawler
A set of Ruby scripts to download information from government website: http://www.siam.mg.gov.br/siam/processo/index.jsp

It uses multiple threads sharing a single SQLite db connection. It was tested downloading 170K+ files.

## Execution order
1. **get_empreendimentos_from_municipio_id.rb**: loads "empreendimentos" from "municipios" that doesn't have too 
much data. Too many "empreendimentos" (around 2000+ on an Intel Core i3) causes Selenium Driver to timeout.
  
2. **get_empreendimentos_from_file.rb**: loads "empreendimentos" from a html file saved on disk.

3. **get_documentos_list.rb**: loads all "documentos" associated with each "empreendimento". It uses 4 threads 
sharing a single SQLite db connection to avoid locked db issues. It also restarts Selenium Driver if system's free 
memory is too low. Firefox consumes a lot of memory when running for a long time.

4. **download_documentos.rb**: downloads files associated to each "documento". It detects and mark files that are
not found or any other error.
  


