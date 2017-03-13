require 'selenium-webdriver'
require 'progress_bar'
require 'sqlite3'

db = SQLite3::Database.new 'db.sqlite3'
db.execute('PRAGMA foreign_keys=ON')

driver = Selenium::WebDriver.for :firefox

base_url = 'http://www.siam.mg.gov.br/siam'
url_cidade_template = "#{base_url}/processo/processo_emprto_emprdor.jsp?pageheader=null&num_pt=&ano_pt=&nome_empreendedor=&cpf_cnpj_emprdor=&num_fob=&ano_fob=&cod_atividades=&cod_outros_municipios=%s&nome_empreendimento=&cpf_cnpj_emp=&tipoProcesso=&num_apefoutorga=&cod_empreendimento=&ano_apefoutorga="

municipios = ['186','67','376','578','447','277','686','701','712','313','702','493','448','367']

municipios.each do |n|

  url = url_cidade_template % n
  driver.navigate.to url
  municipio = driver.find_element(:xpath, '//table[3]/tbody/tr/td[2]/span').text
  tabela_empreendimentos = driver.find_elements(:xpath, "//table[@class='OraTable']/tbody/tr")

  puts 'Downloading ' + municipio

  bar = ProgressBar.new(tabela_empreendimentos.length)
  tabela_empreendimentos.each do |row|
    total = row.find_element(:xpath, './td[4]').text
    if Integer(total) == 0
      bar.increment! tabela_empreendimentos.length
      break
    end

    processo = row.find_element(:xpath, './td[1]').text
    empreendedor = row.find_element(:xpath, './td[2]').text
    empreendimento = row.find_element(:xpath, './td[3]').text

    db.execute('INSERT INTO empreendimentos (municipio, processo, empreendedor, empreendimento) VALUES (?, ?, ?, ?)',
               [ municipio, processo, empreendedor, empreendimento ])

    bar.increment!
  end
end
