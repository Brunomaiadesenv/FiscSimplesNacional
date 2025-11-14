
-- Fiscalizacao_SN_ModeloOficial.sql
-- Modelo fiel ao layout XML oficial da Receita Federal (PGDAS-D 2018 e DEFIS)
-- Ajuste os caminhos dos arquivos XML conforme instruções abaixo.
-- OBS: Execute inicialmente em homologação. Pode ser necessário habilitar 'Ad Hoc Distributed Queries'
--       e garantir permissões do SQL Server no diretório de arquivos.
--       Caminho de exemplo de importação: C:\FiscalizacaoSN\XML_Receita\

-- ===========================
-- Criar banco
-- ===========================
IF DB_ID('base_fiscalizacao_SN') IS NULL
BEGIN
    CREATE DATABASE base_fiscalizacao_SN;
END
GO
USE base_fiscalizacao_SN;
GO

-- ===========================
-- Staging para XML oficiais (raw)
-- ===========================
IF OBJECT_ID('stg_pgdas_xml','U') IS NOT NULL DROP TABLE stg_pgdas_xml;
CREATE TABLE stg_pgdas_xml (
    id INT IDENTITY(1,1) PRIMARY KEY,
    filename NVARCHAR(260),
    xml_doc XML,
    import_dt DATETIME DEFAULT SYSUTCDATETIME()
);

IF OBJECT_ID('stg_defis_xml','U') IS NOT NULL DROP TABLE stg_defis_xml;
CREATE TABLE stg_defis_xml (
    id INT IDENTITY(1,1) PRIMARY KEY,
    filename NVARCHAR(260),
    xml_doc XML,
    import_dt DATETIME DEFAULT SYSUTCDATETIME()
);

-- ===========================
-- Tabelas mapeadas a partir do XSD PGDAS-D
-- (nomes inspirados nos nós XML oficiais)
-- ===========================

-- pgdas_contribuinte (elemento Contribuinte)
IF OBJECT_ID('pgdas_contribuinte','U') IS NOT NULL DROP TABLE pgdas_contribuinte;
CREATE TABLE pgdas_contribuinte (
    cnpj CHAR(14) PRIMARY KEY,
    razaoSocial NVARCHAR(200),
    nomeFantasia NVARCHAR(150),
    inscricaoMunicipal NVARCHAR(50),
    dataAbertura DATE,
    optanteSimples BIT,
    regimeApuracaoAno NVARCHAR(MAX), -- JSON com anos/regimes
    created_at DATETIME DEFAULT SYSUTCDATETIME()
);

-- pgdas_apuracao (elemento Apuracao)
IF OBJECT_ID('pgdas_apuracao','U') IS NOT NULL DROP TABLE pgdas_apuracao;
CREATE TABLE pgdas_apuracao (
    apuracaoId INT IDENTITY(1,1) PRIMARY KEY,
    cnpj CHAR(14),
    periodoApuracao CHAR(7), -- MM/YYYY
    receitaBrutaPeriodo DECIMAL(18,2),
    receitaBrutaInterna DECIMAL(18,2),
    receitaBrutaExterna DECIMAL(18,2),
    rbt12 DECIMAL(18,2),
    rba DECIMAL(18,2),
    situacaoTransmissao NVARCHAR(50),
    dataTransmissao DATETIME,
    valorDevidoTotal DECIMAL(18,2),
    dasEmitido BIT,
    dasNumero NVARCHAR(80),
    observacoes NVARCHAR(400),
    import_dt DATETIME DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_pgdas_contribuinte FOREIGN KEY (cnpj) REFERENCES pgdas_contribuinte(cnpj)
);

-- pgdas_receita (elemento Receita ou ListaReceitas por atividade)
IF OBJECT_ID('pgdas_receita','U') IS NOT NULL DROP TABLE pgdas_receita;
CREATE TABLE pgdas_receita (
    receitaId INT IDENTITY(1,1) PRIMARY KEY,
    cnpj CHAR(14),
    periodoApuracao CHAR(7),
    estabelecimentoId NVARCHAR(60),
    atividadeCodigo NVARCHAR(50),
    descricaoAtividade NVARCHAR(250),
    valorReceita DECIMAL(18,2),
    mercado NVARCHAR(20),
    qualificacaoTributaria NVARCHAR(80),
    ufDestinoIss NVARCHAR(2),
    municipioDestinoIss NVARCHAR(120),
    referenciaDocumento NVARCHAR(200),
    import_dt DATETIME DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_pgdas_receita_contribuinte FOREIGN KEY (cnpj) REFERENCES pgdas_contribuinte(cnpj)
);

-- pgdas_valor_devido (elemento ValorDevido com tributos separados)
IF OBJECT_ID('pgdas_valor_devido','U') IS NOT NULL DROP TABLE pgdas_valor_devido;
CREATE TABLE pgdas_valor_devido (
    id INT IDENTITY(1,1) PRIMARY KEY,
    cnpj CHAR(14),
    periodoApuracao CHAR(7),
    valorIRPJ DECIMAL(18,2),
    valorCSLL DECIMAL(18,2),
    valorCPP DECIMAL(18,2),
    valorICMS DECIMAL(18,2),
    valorISS DECIMAL(18,2),
    valorPIS DECIMAL(18,2),
    valorCOFINS DECIMAL(18,2),
    valorTotal DECIMAL(18,2),
    import_dt DATETIME DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_pgdas_valor_contribuinte FOREIGN KEY (cnpj) REFERENCES pgdas_contribuinte(cnpj)
);

-- ===========================
-- Tabelas mapeadas a partir do XSD DEFIS
-- ===========================

-- defis_identificacao (elemento Identificacao / Contribuinte)
IF OBJECT_ID('defis_identificacao','U') IS NOT NULL DROP TABLE defis_identificacao;
CREATE TABLE defis_identificacao (
    cnpj CHAR(14) PRIMARY KEY,
    razaoSocial NVARCHAR(200),
    nomeFantasia NVARCHAR(150),
    dataAbertura DATE,
    naturezaJuridica NVARCHAR(50),
    qualificacao NVARCHAR(100),
    created_at DATETIME DEFAULT SYSUTCDATETIME()
);

-- defis_declaracao (elemento Declaracao / cabecalho da DEFIS)
IF OBJECT_ID('defis_declaracao','U') IS NOT NULL DROP TABLE defis_declaracao;
CREATE TABLE defis_declaracao (
    defisId INT IDENTITY(1,1) PRIMARY KEY,
    cnpj CHAR(14),
    anoDeclaracao INT,
    tipoDeclaracao NVARCHAR(20),
    dataTransmissao DATE,
    recibo NVARCHAR(80),
    informacoesEconomicas NVARCHAR(MAX),
    pendencias NVARCHAR(400),
    import_dt DATETIME DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_defis_identificacao FOREIGN KEY (cnpj) REFERENCES defis_identificacao(cnpj)
);

-- defis_socios (elemento Socios pessoa fisica/juridica)
IF OBJECT_ID('defis_socios','U') IS NOT NULL DROP TABLE defis_socios;
CREATE TABLE defis_socios (
    socioId INT IDENTITY(1,1) PRIMARY KEY,
    cnpj CHAR(14),
    nomeSocio NVARCHAR(200),
    cpfCnpj NVARCHAR(20),
    partecipacaoPercentual DECIMAL(5,2),
    import_dt DATETIME DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_defis_socios FOREIGN KEY (cnpj) REFERENCES defis_identificacao(cnpj)
);

-- ===========================
-- Documentos fonte (NF-e, NFSe, recibos)
-- ===========================
IF OBJECT_ID('doc_fonte','U') IS NOT NULL DROP TABLE doc_fonte;
CREATE TABLE doc_fonte (
    idDocumento NVARCHAR(120) PRIMARY KEY,
    cnpj CHAR(14),
    tipoDocumento NVARCHAR(40),
    serie NVARCHAR(20),
    numero NVARCHAR(50),
    dataEmissao DATE,
    chaveAcesso NVARCHAR(80),
    valorTotal DECIMAL(18,2),
    valorLiquido DECIMAL(18,2),
    codigoProduto NVARCHAR(80),
    cnae NVARCHAR(20),
    estabelecimentoId NVARCHAR(60),
    arquivoPdfPath NVARCHAR(260),
    hashArquivo NVARCHAR(200),
    import_dt DATETIME DEFAULT SYSUTCDATETIME()
);

-- ===========================
-- Logs e suporte
-- ===========================
IF OBJECT_ID('log_importacao','U') IS NOT NULL DROP TABLE log_importacao;
CREATE TABLE log_importacao (
    id INT IDENTITY(1,1) PRIMARY KEY,
    sourceFile NVARCHAR(260),
    objectName NVARCHAR(100),
    rowsImported INT,
    statusImport NVARCHAR(30),
    message NVARCHAR(400),
    execDt DATETIME DEFAULT SYSUTCDATETIME()
);

-- ===========================
-- Indexes
-- ===========================
CREATE INDEX IX_pgdas_apuracao_cnpj_pa ON pgdas_apuracao(cnpj, periodoApuracao);
CREATE INDEX IX_pgdas_receita_cnpj_pa ON pgdas_receita(cnpj, periodoApuracao);
CREATE INDEX IX_pgdas_valor_cnpj_pa ON pgdas_valor_devido(cnpj, periodoApuracao);
CREATE INDEX IX_defis_declaracao_cnpj_ano ON defis_declaracao(cnpj, anoDeclaracao);

-- ===========================
-- Views de Reconciliação (simplificadas)
-- ===========================
IF OBJECT_ID('vw_pgdas_divergencia','V') IS NOT NULL DROP VIEW vw_pgdas_divergencia;
GO
CREATE VIEW vw_pgdas_divergencia AS
SELECT 
    a.cnpj,
    idt.razaoSocial,
    a.periodoApuracao AS pa,
    a.receitaBrutaPeriodo AS rpa_total,
    ISNULL(SUM(r.valorReceita),0) AS receita_sistema,
    a.receitaBrutaPeriodo - ISNULL(SUM(r.valorReceita),0) AS divergencia,
    CASE WHEN a.receitaBrutaPeriodo = 0 THEN 0
         ELSE ROUND((ABS(a.receitaBrutaPeriodo - ISNULL(SUM(r.valorReceita),0)) / a.receitaBrutaPeriodo) * 100.0,2)
    END AS divergencia_pct
FROM pgdas_apuracao a
LEFT JOIN pgdas_receita r ON r.cnpj = a.cnpj AND r.periodoApuracao = a.periodoApuracao
LEFT JOIN pgdas_contribuinte c ON c.cnpj = a.cnpj
LEFT JOIN defis_identificacao idt ON idt.cnpj = a.cnpj
GROUP BY a.cnpj, idt.razaoSocial, a.periodoApuracao, a.receitaBrutaPeriodo;
GO

IF OBJECT_ID('vw_pgdas_alertas','V') IS NOT NULL DROP VIEW vw_pgdas_alertas;
GO
CREATE VIEW vw_pgdas_alertas AS
SELECT v.*,
       CASE 
         WHEN v.divergencia_pct > 5 THEN 'ALERTA_GRAVE'
         WHEN v.divergencia_pct > 1 THEN 'ALERTA_MEDIO'
         WHEN v.divergencia_pct > 0 THEN 'ATENCAO'
         ELSE 'OK'
       END AS status_alerta
FROM vw_pgdas_divergencia v;
GO

-- ===========================
-- Procedure: importar XML PGDAS-D (exemplo)
-- ===========================
IF OBJECT_ID('usp_importar_pgdas_xml','P') IS NOT NULL DROP PROCEDURE usp_importar_pgdas_xml;
GO
CREATE PROCEDURE usp_importar_pgdas_xml
    @xmlfile NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @xml XML;
    -- Carrega XML
    SELECT @xml = CONVERT(XML, BulkColumn) FROM OPENROWSET(BULK @xmlfile, SINGLE_BLOB) AS x;
    -- Inserir arquivo no staging
    INSERT INTO stg_pgdas_xml (filename, xml_doc) VALUES (@xmlfile, @xml);

    -- Ajuste os paths abaixo conforme o XSD do XML que você recebeu.
    -- Exemplo genérico (mapeie os nomes reais de elementos do XML):
    ;WITH XMLNAMESPACES(DEFAULT 'http://www.receita.fazenda.gov.br/pgdas') -- ajuste se houver namespace
    INSERT INTO pgdas_contribuinte (cnpj, razaoSocial, nomeFantasia, dataAbertura, optanteSimples)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)') AS cnpj,
        T.RazaoSocial.value('.', 'NVARCHAR(200)') AS razao,
        T.NomeFantasia.value('.', 'NVARCHAR(150)') AS fantasia,
        TRY_CAST(T.DataAbertura.value('.', 'DATE') AS DATE),
        CASE WHEN T.Optante.value('.', 'NVARCHAR(5)') = 'S' THEN 1 ELSE 0 END
    FROM stg_pgdas_xml s
    CROSS APPLY s.xml_doc.nodes('/Apuracao/Contribuinte') AS X(T)
    WHERE NOT EXISTS (SELECT 1 FROM pgdas_contribuinte c WHERE c.cnpj = T.CNPJ.value('.', 'CHAR(14)'));

    -- Inserir apuracao (exemplo de extração)
    INSERT INTO pgdas_apuracao (cnpj, periodoApuracao, receitaBrutaPeriodo, receitaBrutaInterna, receitaBrutaExterna, rbt12, rba, valorDevidoTotal, situacaoTransmissao, dataTransmissao)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)') AS cnpj,
        T.Periodo.value('.', 'CHAR(7)') AS pa,
        TRY_CAST(T.ReceitaBrutaPeriodo.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.ReceitaBrutaInterna.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.ReceitaBrutaExterna.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.RBT12.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.RBA.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.ValorDevidoTotal.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        T.Situacao.value('.', 'NVARCHAR(50)'),
        TRY_CAST(T.DataTransmissao.value('.', 'DATE') AS DATE)
    FROM stg_pgdas_xml s
    CROSS APPLY s.xml_doc.nodes('/Apuracao/Contribuinte/Apuracao') AS X(T);

    -- Inserir receitas detalhadas (ajuste path conforme XML)
    INSERT INTO pgdas_receita (cnpj, periodoApuracao, estabelecimentoId, atividadeCodigo, descricaoAtividade, valorReceita, mercado, qualificacaoTributaria, ufDestinoIss, municipioDestinoIss, referenciaDocumento)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)') AS cnpj,
        T.Periodo.value('.', 'CHAR(7)') AS pa,
        T.Estabelecimento.value('.', 'NVARCHAR(60)') AS estab,
        T.CNAE.value('.', 'NVARCHAR(50)') AS cnae,
        T.Descricao.value('.', 'NVARCHAR(250)') AS descAtiv,
        TRY_CAST(T.Valor.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        T.Mercado.value('.', 'NVARCHAR(20)'),
        T.Qualificacao.value('.', 'NVARCHAR(80)'),
        T.UFDestino.value('.', 'NVARCHAR(2)'),
        T.MunDest.value('.', 'NVARCHAR(120)'),
        T.ReferenciaDoc.value('.', 'NVARCHAR(200)')
    FROM stg_pgdas_xml s
    CROSS APPLY s.xml_doc.nodes('/Apuracao/Contribuinte/Apuracao/Receitas/Receita') AS X(T);

    -- Inserir valores devidos por tributo (exemplo)
    INSERT INTO pgdas_valor_devido (cnpj, periodoApuracao, valorIRPJ, valorCSLL, valorCPP, valorICMS, valorISS, valorPIS, valorCOFINS, valorTotal)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)'),
        T.Periodo.value('.', 'CHAR(7)'),
        TRY_CAST(T.IRPJ.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.CSLL.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.CPP.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.ICMS.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.ISS.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.PIS.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.COFINS.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2)),
        TRY_CAST(T.Total.value('.', 'DECIMAL(18,2)') AS DECIMAL(18,2))
    FROM stg_pgdas_xml s
    CROSS APPLY s.xml_doc.nodes('/Apuracao/Contribuinte/Apuracao/ValorDevido') AS X(T);

    -- Log simples
    INSERT INTO log_importacao(sourceFile, objectName, rowsImported, statusImport, message)
    VALUES (@xmlfile, 'PGDAS_XML', 1, 'OK', 'Import realizado (verificar mapeamento de nodes)');
END;
GO

-- ===========================
-- Procedure: importar XML DEFIS (exemplo)
-- ===========================
IF OBJECT_ID('usp_importar_defis_xml','P') IS NOT NULL DROP PROCEDURE usp_importar_defis_xml;
GO
CREATE PROCEDURE usp_importar_defis_xml
    @xmlfile NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @xml XML;
    SELECT @xml = CONVERT(XML, BulkColumn) FROM OPENROWSET(BULK @xmlfile, SINGLE_BLOB) AS x;
    INSERT INTO stg_defis_xml(filename, xml_doc) VALUES (@xmlfile, @xml);

    -- Ajuste paths conforme XSD DEFIS
    INSERT INTO defis_identificacao (cnpj, razaoSocial, nomeFantasia, dataAbertura, naturezaJuridica, qualificacao)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)'),
        T.RazaoSocial.value('.', 'NVARCHAR(200)'),
        T.NomeFantasia.value('.', 'NVARCHAR(150)'),
        TRY_CAST(T.DataAbertura.value('.', 'DATE') AS DATE),
        T.Natureza.value('.', 'NVARCHAR(50)'),
        T.Qualificacao.value('.', 'NVARCHAR(100)')
    FROM stg_defis_xml s
    CROSS APPLY s.xml_doc.nodes('/Declaracao/Identificacao') AS X(T)
    WHERE NOT EXISTS (SELECT 1 FROM defis_identificacao d WHERE d.cnpj = T.CNPJ.value('.', 'CHAR(14)'));

    INSERT INTO defis_declaracao (cnpj, anoDeclaracao, tipoDeclaracao, dataTransmissao, recibo, informacoesEconomicas, pendencias)
    SELECT
        T.CNPJ.value('.', 'CHAR(14)'),
        TRY_CAST(T.Ano.value('.', 'INT') AS INT),
        T.Tipo.value('.', 'NVARCHAR(20)'),
        TRY_CAST(T.DataTransmissao.value('.', 'DATE') AS DATE),
        T.Recibo.value('.', 'NVARCHAR(80)'),
        T.InfoEconom.value('.', 'NVARCHAR(MAX)'),
        T.Pendencias.value('.', 'NVARCHAR(400)')
    FROM stg_defis_xml s
    CROSS APPLY s.xml_doc.nodes('/Declaracao') AS X(T);

    INSERT INTO log_importacao(sourceFile, objectName, rowsImported, statusImport, message)
    VALUES (@xmlfile, 'DEFIS_XML', 1, 'OK', 'Import DEFIS realizado (verificar nodes)');
END;
GO

-- ===========================
-- Exemplo de uso (ajuste caminhos)
-- ===========================
-- EXEC usp_importar_pgdas_xml 'C:\FiscalizacaoSN\XML_Receita\PGDASD_EXEMPLO.xml';
-- EXEC usp_importar_defis_xml 'C:\FiscalizacaoSN\XML_Receita\DEFIS_EXEMPLO.xml';

-- ===========================
-- Consulta exemplo para identificar divergencias significativas
-- ===========================
SELECT cnpj, pa, rpa_total, receita_sistema, divergencia, divergencia_pct
FROM vw_pgdas_divergencia
WHERE ABS(divergencia) > 100.00
ORDER BY ABS(divergencia) DESC;
