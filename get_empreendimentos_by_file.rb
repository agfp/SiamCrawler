require 'nokogiri'
require 'progress_bar'
require 'sqlite3'

db = SQLite3::Database.new 'db.sqlite3'
db.execute('PRAGMA foreign_keys=ON')

#arquivos = ['BH', 'Valadares', 'Uberaba', 'Uberlandia', 'JF', 'NovaLima']
arquivos = ['JF', 'Valadares', 'Uberaba', 'Uberlandia', 'NovaLima']

arquivos.each do |f|
  page = Nokogiri::HTML(open("#{f}.html"))

  municipio = page.xpath('//table[3]//td[2]').text.strip
  tabela_empreendimentos = page.xpath("//table[@class='OraTable']/tbody/tr")

  puts 'Downloading ' + municipio

  bar = ProgressBar.new(tabela_empreendimentos.length)
  tabela_empreendimentos.each do |row|
    total = row.xpath('./td[4]').text
    if Integer(total) == 0
      bar.increment! tabela_empreendimentos.length
      break
    end

    processo = row.xpath('./td[1]').text
    empreendedor = row.xpath('./td[2]').text
    empreendimento = row.xpath('./td[3]').text

    db.execute('INSERT INTO empreendimento (municipio, processo, empreendedor, empreendimento) VALUES (?, ?, ?, ?)',
               [municipio, processo, empreendedor, empreendimento])

    bar.increment!
  end
end