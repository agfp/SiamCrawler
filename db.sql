--
-- File generated with SQLiteStudio v3.1.1 on seg mar 13 19:13:48 2017
--
-- Text encoding used: UTF-8
--
PRAGMA foreign_keys = off;
BEGIN TRANSACTION;

-- Table: documentos
CREATE TABLE documentos (
    id                INTEGER PRIMARY KEY AUTOINCREMENT
                              NOT NULL,
    empreendimento_fk INTEGER REFERENCES empreendimentos (id) ON DELETE CASCADE
                              NOT NULL,
    tipo_fk           INTEGER REFERENCES tipos (id) 
                              NOT NULL,
    processo          STRING  NOT NULL,
    protocolo         STRING  NOT NULL,
    documento         STRING  NOT NULL,
    link              STRING  NOT NULL,
    curl_exit_code    STRING,
    http_status       STRING
);


-- Table: documentos_selecionados
CREATE TABLE documentos_selecionados (
    nome STRING NOT NULL
);


-- Table: empreendimentos
CREATE TABLE empreendimentos (
    id             INTEGER PRIMARY KEY AUTOINCREMENT
                           NOT NULL,
    municipio      STRING  NOT NULL,
    processo       STRING  NOT NULL,
    empreendedor   STRING  NOT NULL,
    empreendimento STRING  NOT NULL,
    completo       INTEGER,
    running        INTEGER
);


-- Table: tipos
CREATE TABLE tipos (
    id    INTEGER PRIMARY KEY AUTOINCREMENT
                  NOT NULL,
    orgao STRING  NOT NULL,
    tipo  STRING  NOT NULL
);


-- View: downloads
CREATE VIEW downloads AS
    SELECT D.id AS documento_id,
           E.municipio AS municipio,
           SUBSTR(E.empreendedor || ' - ' || E.empreendimento, 0, 250) AS empreendimento,
           T.orgao || ' - ' || T.tipo AS tipo,
           SUBSTR(D.id || ' - ' || D.processo || ' - ' || D.documento, 0, 250) || '.pdf' AS arquivo,
           D.link AS link,
           D.curl_exit_code AS curl_exit_code,
           D.http_status AS http_status
      FROM documentos AS D
           INNER JOIN
           empreendimentos AS E ON D.empreendimento_fk = E.id
           INNER JOIN
           tipos AS T ON D.tipo_fk = T.id
     WHERE D.documento IN (
               SELECT *
                 FROM documentos_selecionados
           );


COMMIT TRANSACTION;
PRAGMA foreign_keys = on;
