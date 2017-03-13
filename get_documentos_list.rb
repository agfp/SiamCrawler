# coding: utf-8
require 'selenium-webdriver'
require 'sqlite3'
require 'thread'
require 'progress_bar'

N_THREADS = 4

@base_url = 'http://www.siam.mg.gov.br/siam'
@url_processo = "#{@base_url}/processo/processo_emprto_emprdor.jsp?pageheader=null&num_pt=%s&ano_pt=%s&nome_empreendedor=&cpf_cnpj_emprdor=&num_fob=&ano_fob=&cod_atividades=&cod_outros_municipios=&nome_empreendimento=&cpf_cnpj_emp=&tipoProcesso=&num_apefoutorga=&cod_empreendimento=&ano_apefoutorga="

@lock = Mutex.new
@lock_insert = Mutex.new

@db = SQLite3::Database.new 'db.sqlite3'
@db.execute('PRAGMA foreign_keys=ON')
@db.execute('UPDATE empreendimentos SET running = null WHERE running = 1 AND completo IS NULL')

total = @db.execute('SELECT count(id) FROM empreendimentos')[0][0]
completed = @db.execute('SELECT count(id) FROM empreendimentos WHERE completo = 1')[0][0]
@bar = ProgressBar.new(total)
@bar.increment! completed

@restart_driver = []
N_THREADS.times { @restart_driver << false }

def download_loop(index)

  driver = Selenium::WebDriver.for :firefox

  while true

    if @restart_driver[index]
      @restart_driver[index] = false
      puts "#{Time.now}: Driver \##{index} restarted"
      driver.quit
      sleep(rand(10))
      driver = Selenium::WebDriver.for :firefox
    end

    empreendimento_id = 0
    processo = ''

    @lock.synchronize do
      query = @db.execute('SELECT id, processo FROM empreendimentos WHERE running IS NULL AND completo IS NULL LIMIT 1')
      if query.any?
        empreendimento_id = Integer(query[0][0])
        processo = query[0][1]
        @db.execute('UPDATE empreendimentos SET running = 1 WHERE id = ?', [empreendimento_id])
        @bar.increment!
      end
    end

    break if empreendimento_id == 0

    @db.execute('DELETE FROM documentos WHERE empreendimento_fk = ?', [empreendimento_id])

    url = @url_processo % [ processo.split('/')[0], processo.split('/')[1] ]
    driver.navigate.to url

    tipos_disponiveis = driver.find_elements(:xpath, '//body/table[6]//tr[not(@bgcolor)]/td[2]//a')

    lista_tipos = []
    tipos_disponiveis.each do |tipo|
      orgao = tipo.find_element(:xpath, './ancestor::tr/td[1]').text
      link = @base_url + tipo.attribute('href')[23..-3]
      descricao = tipo.text

      result = @db.execute('SELECT id FROM tipos WHERE orgao = ? AND tipo = ?', [orgao, descricao])

      tipo_id = if result.any?
                  result[0][0]
                else
                  @lock_insert.synchronize do
                    @db.execute('INSERT INTO tipos(orgao, tipo) VALUES (?, ?)', [orgao, descricao])
                    @db.execute('SELECT last_insert_rowid()')[0][0]
                  end
                end

      lista_tipos << {id: tipo_id,
                      orgao: orgao,
                      tipo: descricao,
                      link: link}

    end

    lista_tipos.each do |tipo|
      driver.navigate.to tipo[:link]
      lista_processos = []
      coluna_link = case [tipo[:orgao], tipo[:tipo]]
                      when ['IGAM', 'OUTORGA']
                        7
                      when ['-', 'FOB - Formulário de Orientação Básica'],
                          ['FEAM', 'Auto Infração'],
                          ['IEF', 'Auto Infração']
                        6
                      else
                        8
                    end
      tabela_processos = driver.find_elements(:xpath, '//table//table/tbody/tr')
      tabela_processos.each do |linha|
        lista_processos << {processo: linha.find_element(:xpath, './td[2]').text,
                            link: linha.find_element(:xpath, "./td[#{coluna_link}]//a").attribute('href')}
      end

      lista_processos.each do |processo|
        driver.navigate.to processo[:link]
        tabela_documentos = driver.find_elements(:xpath, '//table/tbody/tr')
        tabela_documentos.each do |linha|
          a = linha.find_elements(:xpath, './td[6]//a')
          unless a.length == 0
            protocolo = linha.find_element(:xpath, './td[1]').text
            documento = linha.find_element(:xpath, './td[2]').text
            link = a[0].attribute('href')[36..-3]
            @lock_insert.synchronize do
              @db.execute('INSERT INTO documentos(empreendimento_fk, tipo_fk, processo, protocolo, documento, link) VALUES (?,?,?,?,?,?)',
                          [empreendimento_id, tipo[:id], processo[:processo], protocolo, documento, link])
            end
          end
        end
      end
    end

    @db.execute('UPDATE empreendimentos SET completo = 1 WHERE id = ?', [empreendimento_id])
  end
end

def check_memory
  while true
      meminfo = `cat /proc/meminfo | grep MemAvailable`
      available = Integer(meminfo.split(' ')[1])
      if available < 2000000
        (1..N_THREADS).each { |n| @restart_driver[n] = true }
        puts "#{Time.now}: Memory low"
      end
    sleep(120)
  end
end


threads = []
memory_thread = Thread.new { check_memory }
(1..N_THREADS).each { |n| threads << Thread.new { download_loop(n) } }

threads.map { |t| t.join }
memory_thread.kill
