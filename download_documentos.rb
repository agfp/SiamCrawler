require 'sqlite3'
require 'fileutils'
require 'shellwords'
require 'i18n'
require 'progress_bar'

I18n.available_locales = [:en]
def sanitize_filename(filename)
  filename = I18n.transliterate(filename)
  filename.gsub(/[^a-z0-9\-\s\.]+/i, '_')
end

db = SQLite3::Database.new 'db.sqlite3'
db.execute('PRAGMA foreign_keys=ON')

total = db.execute('SELECT count(documento_id) FROM downloads')[0][0]
completed = db.execute('SELECT count(documento_id) FROM downloads WHERE curl_exit_code IS NOT NULL')[0][0]

bar = ProgressBar.new(total)
bar.increment! completed


query = 'SELECT * FROM downloads WHERE curl_exit_code IS NULL LIMIT 1'
while (result = db.execute(query)).any?
  documento_id = result[0][0]
  municipio = sanitize_filename(result[0][1])
  empreendimento = sanitize_filename(result[0][2])
  tipo = sanitize_filename(result[0][3])
  arquivo = sanitize_filename(result[0][4])
  link = result[0][5]

  folder = "%s/%s/%s" % [municipio, empreendimento, tipo]
  arquivo_path = "%s/%s" % [folder, arquivo]
  FileUtils::mkdir_p(folder) unless File.exists?(folder)

  `curl -s -f -o #{arquivo_path.shellescape} #{link}`
  exit_code = $?.exitstatus
  http_status = exit_code == 22 ? `curl -s -o /dev/null -I -w "\%{http_code}" #{link}` : nil

  db.execute('UPDATE documentos SET curl_exit_code = ?, http_status = ? WHERE id = ?', [exit_code, http_status, documento_id])
  bar.increment!
end
