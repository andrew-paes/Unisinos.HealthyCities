-- BI
CREATE SCHEMA IF NOT EXISTS bi
    AUTHORIZATION postgres;

CREATE TABLE bi.dim_estabelecimentos
(
 "id"           uuid NOT NULL,
 codigo_unidade character(13) NULL,
 cnes           character(7) NULL,
 razao_social   citext NULL,
 nome_fantasia  citext NULL,
 logradouro     citext NULL,
 endereco       citext NULL,
 complemento    citext NULL,
 cep            character(8) NULL,
 latitude       decimal NULL,
 longitude      decimal NULL,
 CONSTRAINT PK_id_dim_estabelecimento PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_habilitacoes
(
 "id"      uuid NOT NULL,
 codigo    citext NOT NULL,
 descricao citext NOT NULL,
 apelido   citext NULL,
 ativo     boolean NOT NULL,
 CONSTRAINT PK_id_dim_habilitacao PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_localidades
(
 "id"                   uuid NOT NULL,
 municipio_cod_correios int NOT NULL,
 municipio_nome         varchar(256) NOT NULL,
 regiao_nome            varchar(256) NOT NULL,
 regiao_descricao       varchar(4000) NOT NULL,
 bairro_cod_correios    int NOT NULL,
 bairro_nome            varchar(256) NOT NULL,
 bairro_area_ha         decimal NULL,
 bairro_popalacao       int NULL,
 bairro_renda_media     decimal NULL,
 CONSTRAINT PK_id_dim_localidade PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_servicos
(
 "id"      uuid NOT NULL,
 codigo    citext NOT NULL,
 descricao citext NOT NULL,
 ativo     boolean NOT NULL,
 CONSTRAINT PK_id_dim_servico PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_tempos
(
 "id" uuid NOT NULL,
 ano  int NOT NULL,
 mes  int NOT NULL,
 CONSTRAINT PK_id_dim_tempo PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_tipos_estabelecimentos
(
 "id" uuid NOT NULL,
 nome citext NOT NULL,
 CONSTRAINT PK_id_dim_tipo_estabelecimento PRIMARY KEY ( "id" )
);

CREATE TABLE bi.dim_tipos_prestadores
(
 "id" uuid NOT NULL,
 nome citext NOT NULL,
 CONSTRAINT PK_id_dim_tipo_prestador PRIMARY KEY ( "id" )
);

CREATE TABLE bi.fact_estabelecimentos_capacidades
(
 "id"                     uuid NOT NULL,
 id_tempo                 uuid NOT NULL,
 id_localidade            uuid NOT NULL,
 id_estabelecimento       uuid NOT NULL,
 id_tipo_estabelecimento  uuid NOT NULL,
 id_tipo_prestador        uuid NOT NULL,
 leitos                   int NULL,
 leitos_sus               int NULL,
 atende_sus               boolean NULL, 
 CONSTRAINT PK_id_fact_estabelecimento_detalhe PRIMARY KEY ("id" ),
 CONSTRAINT FK_id_tempo FOREIGN KEY(id_tempo) REFERENCES bi.dim_tempos(id),
 CONSTRAINT FK_id_localidade FOREIGN KEY(id_localidade) REFERENCES bi.dim_localidades(id),
 CONSTRAINT FK_id_estabelecimento FOREIGN KEY(id_estabelecimento) REFERENCES bi.dim_estabelecimentos(id),
 CONSTRAINT FK_id_tipo_estabelecimento FOREIGN KEY(id_tipo_estabelecimento) REFERENCES bi.dim_tipos_estabelecimentos(id),
 CONSTRAINT FK_id_tipo_prestador FOREIGN KEY(id_tipo_prestador) REFERENCES bi.dim_tipos_prestadores(id)
);

CREATE TABLE bi.fact_estabelecimentos_servicos
(
 "id"                     		uuid NOT NULL,
 id_estabelecimento_capacidade  uuid NOT NULL,
 id_servico               		uuid NULL,
 ds_servico_especializado citext NULL,
 ambulatorial_sus         boolean NULL,
 ambulatorial             boolean NULL,
 hospitalar_sus           boolean NULL,
 hospitalar               boolean NULL,
 CONSTRAINT PK_id_fact_estabelecimento_servico PRIMARY KEY ("id" ),
 CONSTRAINT FK_id_estabelecimento_capacidade FOREIGN KEY(id_estabelecimento_capacidade) REFERENCES bi.fact_estabelecimentos_capacidades(id),
 CONSTRAINT FK_id_servico FOREIGN KEY(id_servico) REFERENCES bi.dim_servicos(id)
);

CREATE TABLE bi.fact_estabelecimentos_habilitacoes
(
 "id"                     		uuid NOT NULL,
 id_estabelecimento_capacidade  uuid NOT NULL,
 id_habilitacao           		uuid NULL,
 CONSTRAINT PK_id_fact_estabelecimento_habilitacao PRIMARY KEY ("id" ),
 CONSTRAINT FK_id_estabelecimento_capacidade FOREIGN KEY(id_estabelecimento_capacidade) REFERENCES bi.fact_estabelecimentos_capacidades(id),
 CONSTRAINT FK_id_habilitacao FOREIGN KEY(id_habilitacao) REFERENCES bi.dim_habilitacoes(id)
);

-- Working
WITH cte AS (
    SELECT DISTINCT
		co_habilitacao,
		CASE
			WHEN no_habilitacao < 'NÃO ACHOU' THEN 'DESCONHECIDO'
		ELSE
			no_habilitacao
		END AS "no_habilitacao"
	FROM cnes.estabelecimentos_habilitacoes
	ORDER BY co_habilitacao, no_habilitacao
)
INSERT INTO bi.dim_habilitacoes
SELECT uuid_generate_v4(), co_habilitacao AS codigo, no_habilitacao AS descricao, NULL AS apelido, TRUE as ativo
FROM cte;

WITH cte AS (
    SELECT DISTINCT
		co_servico,
		ds_servico_especializado
	FROM cnes.estabelecimentos_servicos
	ORDER BY co_servico, ds_servico_especializado
)
INSERT INTO bi.dim_servicos
SELECT uuid_generate_v4(), co_servico AS codigo, ds_servico_especializado AS descricao, TRUE as ativo
FROM cte;

WITH cte AS (
    SELECT DISTINCT
		tipo_estabelecimento
	FROM cnes.estabelecimentos
	WHERE tipo_estabelecimento IS NOT NULL
		AND tipo_estabelecimento <> ''
	ORDER BY tipo_estabelecimento
)
INSERT INTO bi.dim_tipos_estabelecimentos
SELECT uuid_generate_v4(), tipo_estabelecimento AS nome
FROM cte;

WITH cte AS (
    SELECT DISTINCT
		tipo_prestador
	FROM cnes.estabelecimentos
	WHERE tipo_prestador IS NOT NULL
		AND tipo_prestador <> ''
	ORDER BY tipo_prestador
)
INSERT INTO bi.dim_tipos_prestadores
SELECT uuid_generate_v4(), tipo_prestador AS nome
FROM cte;

WITH cte AS (
    SELECT DISTINCT
		*
	FROM cnes.estabelecimentos
	WHERE co_unidade IS NOT NULL
		AND co_unidade LIKE '431490%'
		--AND co_cnes = '3007847'
	ORDER BY co_unidade
)
INSERT INTO bi.dim_estabelecimentos
SELECT uuid_generate_v4(), 
	co_unidade AS codigo_unidade,
	co_cnes AS cnes,
	no_razao_social AS razao_social,
	no_fantasia AS nome_fantasia,
	no_logradouro AS logradouro,
	nu_endereco AS numero,
	no_complemento AS complemento,
	co_cep AS cep,
	nu_latitude AS latitude,
	nu_longitude AS longitude
FROM cte;

WITH cte AS (
    SELECT DISTINCT
		*
	FROM cnes.estabelecimentos ce
	INNER JOIN bi.dim_estabelecimentos bie ON bie.codigo_unidade = ce.co_unidade
	WHERE ce.co_unidade IS NOT NULL
		AND ce.co_unidade LIKE '431490%'
	ORDER BY bie.codigo_unidade
)
--INSERT INTO bi.dim_estabelecimentos
SELECT uuid_generate_v4(), 
	co_unidade AS codigo_unidade,
	co_cnes AS cnes,
	no_razao_social AS razao_social,
	no_fantasia AS nome_fantasia,
	no_logradouro AS logradouro,
	nu_endereco AS numero,
	no_complemento AS complemento,
	co_cep AS cep,
	nu_latitude AS latitude,
	nu_longitude AS longitude
FROM cte;

SELECT *
FROM cnes.rl_estab_complementar
WHERE competencia = '2024/03'
	AND co_unidade = '4314902237156'
ORDER BY co_unidade, competencia;

SELECT co_unidade, SUM(qt_exist), SUM(qt_sus), competencia
FROM cnes.rl_estab_complementar
WHERE competencia = '2024/03'
	AND co_unidade = '4314902237156'
GROUP BY co_unidade, competencia
ORDER BY co_unidade, competencia;

SELECT DISTINCT ce.co_unidade, SUM(cec.qt_exist), SUM(cec.qt_sus), cec.competencia
FROM cnes.estabelecimentos ce
INNER JOIN cnes.rl_estab_complementar cec ON cec.co_unidade = ce.co_unidade AND cec.competencia = '2024/03'
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
GROUP BY ce.co_unidade, cec.competencia
ORDER BY ce.co_unidade, cec.competencia;

SELECT DISTINCT no_bairro
FROM cnes.estabelecimentos ce
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
ORDER BY no_bairro;

SELECT DISTINCT no_bairro
FROM cnes.estabelecimentos ce
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
ORDER BY no_bairro;

--INSERT INTO bi.fact_estabelecimentos_capacidades
SELECT DISTINCT 
	uuid_generate_v4() AS id,
	uuid('ccd1ce12-4ed1-4f3b-bae5-35ab59662edd') AS id_tempo,
	bl.id AS id_localidade,
	be.id AS id_estabelecimento,
	bte.id AS id_tipo_estabelecimento,
	btp.id AS id_tipo_prestador,
	SUM(cec.qt_exist) AS leitos,
	SUM(cec.qt_sus) AS leitos_sus,
	CASE WHEN ce.atende_sus = 'Sim' THEN TRUE
		ELSE FALSE
		END AS "atende_sus"
FROM cnes.estabelecimentos ce
LEFT JOIN cnes.rl_estab_complementar cec ON cec.co_unidade = ce.co_unidade AND competencia = '2024/03'
--
INNER JOIN bi.dim_localidades bl ON bl.bairro_nome = ce.no_bairro
INNER JOIN bi.dim_estabelecimentos be ON be.codigo_unidade = ce.co_unidade
INNER JOIN bi.dim_tipos_estabelecimentos bte ON bte.nome = ce.tipo_estabelecimento
INNER JOIN bi.dim_tipos_prestadores btp ON btp.nome = ce.tipo_prestador
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
	--AND ce.co_unidade = '4314902237571'
GROUP BY
	bl.id,
	be.id,
	bte.id,
	btp.id,
	ce.atende_sus;
	
--INSERT INTO bi.fact_estabelecimentos_servicos
SELECT DISTINCT
	uuid_generate_v4() AS id,
	bec.id AS id_estabelecimento_capacidade,
	bs.id AS id_servico,
	ces.ds_servico_especializado,
	CASE WHEN ces.ambulatorial_sus = 'Sim' THEN TRUE
		ELSE FALSE
		END AS "ambulatorial_sus",
	CASE WHEN ces.ambulatorial = 'Sim' THEN TRUE
		ELSE FALSE
		END AS "ambulatorial",
	CASE WHEN ces.hospitalar_sus = 'Sim' THEN TRUE
		ELSE FALSE
		END AS "hospitalar_sus",
	CASE WHEN ces.hospitalar = 'Sim' THEN TRUE
		ELSE FALSE
		END AS "hospitalar"
FROM cnes.estabelecimentos ce
INNER JOIN bi.dim_estabelecimentos be ON be.codigo_unidade = ce.co_unidade
INNER JOIN bi.fact_estabelecimentos_capacidades bec ON bec.id_estabelecimento = be.id
INNER JOIN cnes.estabelecimentos_servicos ces ON ces.co_unidade = ce.co_unidade
INNER JOIN bi.dim_servicos bs ON bs.codigo = ces.co_servico
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
	--AND ce.co_unidade = '4314902237571';

--INSERT INTO bi.fact_estabelecimentos_habilitacoes
SELECT DISTINCT
	uuid_generate_v4() AS id,
	bec.id AS id_estabelecimento_capacidade,
	bh.id AS id_habilitacao
FROM cnes.estabelecimentos ce
INNER JOIN bi.dim_estabelecimentos be ON be.codigo_unidade = ce.co_unidade
INNER JOIN bi.fact_estabelecimentos_capacidades bec ON bec.id_estabelecimento = be.id
INNER JOIN cnes.estabelecimentos_habilitacoes ceh ON ceh.co_unidade = ce.co_unidade
INNER JOIN bi.dim_habilitacoes bh ON bh.codigo = ceh.co_habilitacao
WHERE ce.co_unidade IS NOT NULL
	AND ce.co_unidade LIKE '431490%'
	--AND ce.co_unidade = '4314902237571';
	
SELECT 
	l.regiao_nome,
	l.regiao_descricao,
	SUM(l.bairro_area_ha) AS area_ha,
	SUM(l.bairro_popalacao) AS populacao,
	AVG(l.bairro_renda_media) AS renda_media,
	(SUM(l.bairro_popalacao) * AVG(l.bairro_renda_media)) AS poder_aquisitivo
FROM bi.dim_localidades l
GROUP BY l.regiao_nome, l.regiao_descricao
ORDER BY l.regiao_nome, l.regiao_descricao;

SELECT 
	l.regiao_nome,
	l.regiao_descricao,
	SUM(l.bairro_area_ha) AS area_ha,
	SUM(l.bairro_popalacao) AS populacao,
	AVG(l.bairro_renda_media) AS renda_media,
	(SUM(l.bairro_popalacao) * AVG(l.bairro_renda_media)) AS poder_aquisitivo,
	tp.nome,
	COUNT(tp.id)
FROM bi.dim_localidades l
INNER JOIN bi.fact_estabelecimentos_capacidades ec ON ec.id_localidade = l.id
INNER JOIN bi.dim_tipos_prestadores tp ON tp.id = ec.id_tipo_prestador
GROUP BY l.regiao_nome, l.regiao_descricao, tp.nome
ORDER BY l.regiao_nome, l.regiao_descricao, tp.nome;

SELECT 
	l.regiao_nome,
	l.regiao_descricao,
	tp.nome,
	COUNT(tp.id)
FROM bi.dim_localidades l
INNER JOIN bi.fact_estabelecimentos_capacidades ec ON ec.id_localidade = l.id
INNER JOIN bi.dim_tipos_prestadores tp ON tp.id = ec.id_tipo_prestador
GROUP BY l.regiao_nome, l.regiao_descricao, tp.nome
ORDER BY l.regiao_nome, l.regiao_descricao, tp.nome;

---------
INSERT INTO bi.dim_localidades(id, municipio_cod_correios, municipio_nome, regiao_nome, regiao_descricao, bairro_cod_correios, bairro_nome, bairro_area_ha, bairro_popalacao, bairro_renda_media)
	VALUES 
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301405, 'Auxiliadora', 84.5, 9683, 8.89),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301406, 'Azenha', 138.8, 13804, 5.34),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301407, 'Bela Vista', 102.4, 11787, 15.8),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301408, 'Bom Fim', 49.5, 11593, 7.2),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301401, 'Centro Histórico', 243.5, 39154, 5.85),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301402, 'Cidade Baixa', 76.2, 15739, 5.3),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301409, 'Farroupilha', 59.3, 961, 8.1),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301410, 'Floresta', 186.7, 11596, 4.82),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301411, 'Independência', 44.2, 8112, 8.69),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301412, 'Jardim Botânico', 203.6, 12521, 6.78),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301413, 'Menino Deus', 230.1, 31650, 7.95),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301414, 'Moinhos de Vento', 131.2, 11937, 12.03),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301415, 'Montserrat', 79.5, 11236, 11.38),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301416, 'Petrópolis', 336.8, 37496, 9.69),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301417, 'Praia de Belas', 257.4, 2281, 6.24),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301418, 'Rio Branco', 134.1, 17531, 10.9),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301419, 'Santa Cecília', 68, 5768, 6.92),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 1', 'Centro', 4301420, 'Santana', 153.4, 20723, 6.63),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301421, 'Anchieta', 917.5, 2024, 1.49),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301422, 'Arquipélago', 4420, 8330, 1.85),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301423, 'Boa Vista', 168.8, 10053, 11.08),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301424, 'Cristo Redentor', 143.2, 16455, 5.26),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301425, 'Farrapos', 226.7, 18986, 1.85),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301426, 'Higienópolis', 106.4, 10724, 9.78),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301427, 'Humaitá', 362.2, 11502, 3.55),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301428, 'Jardim Europa', 76.3, 2299, 12.84),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301429, 'Jardim Floresta', 72.3, 3307, 3.16),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301430, 'Jardim Lindóia', 87.8, 7417, 8.85),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301431, 'Jardim São Pedro', 103.1, 3967, 5.04),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301432, 'Navegantes', 225.8, 4327, 3.22),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301433, 'Passo D’Areia', 209.9, 21968, 4.73),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301434, 'Santa Maria Goretti', 78.4, 3509, 4.01),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301435, 'São Geraldo', 174.2, 8681, 3.97),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301436, 'São João', 158.9, 12226, 6.56),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301437, 'São Sebastião', 106.9, 7019, 4.78),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 2', 'Humaitá, Navegantes, Ilhas e Noroeste', 4301438, 'Vila Ipiranga', 181.6, 18659, 4.6),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301439, 'Costa e Silva', 179.4, 15842, 2.03),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301440, 'Jardim Itu', 255.5, 17853, 5.42),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301441, 'Jardim Leopoldina', 129.9, 18016, 2.65),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301442, 'Parque Santa Fé', 173.1, 6376, 4.63),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301443, 'Passo das Pedras', 229.8, 15902, 1.76),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301444, 'Rubem Berta', 269.4, 33168, 2.16),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301445, 'Santa Rosa de Lima', 548.4, 35333, 1.88),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 3', 'Norte e Eixo Baltazar', 4301446, 'Sarandi', 2456.7, 59711, 3.08),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301447, 'Bom Jesus', 210, 28675, 2.45),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301448, 'Chácara das Pedras', 108.5, 6668, 11.55),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301449, 'Jardim Carvalho', 392.3, 25386, 3.24),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301450, 'Jardim do Salso', 85.5, 4405, 5.96),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301451, 'Jardim Sabará', 208.4, 13530, 3.97),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301452, 'Mário Quintana', 750.7, 38116, 1.54),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301453, 'Morro Santana', 574.5, 19338, 3.09),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301454, 'Três Figueiras', 133.4, 4070, 16.1),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 4', 'Leste e Nordeste', 4301455, 'Vila Jardim', 146.7, 13189, 3.53),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301456, 'Belém Velho', 1486.4, 10835, 2.1),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301457, 'Cascata', 535, 13013, 1.77),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301458, 'Cristal', 406.7, 31946, 4.26),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301459, 'Glória', 353.3, 17067, 3.06),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301460, 'Medianeira', 139.8, 11223, 4.68),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 5', 'Glória, Cruzeiro e Cristal', 4301461, 'Santa Tereza', 451.8, 39577, 3.35),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301462, 'Aberta dos Morros', 376.4, 7146, 2.95),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301463, 'Camaquã', 190.1, 17938, 3.65),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301464, 'Campo Novo', 359.9, 8766, 2.04),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301465, 'Cavalhada', 376.1, 29299, 3.88),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301466, 'Espírito Santo', 159.3, 5606, 5.8),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301467, 'Guarujá', 168.5, 4811, 5.24),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301468, 'Hípica', 1033.2, 18645, 3.06),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301469, 'Ipanema', 380, 13728, 6.94),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301470, 'Jardim Isabel', 70.5, 2835, 13.27),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301471, 'Nonoai', 446.3, 25160, 4.18),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301472, 'Pedra Redonda', 66.6, 274, 16.61),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301473, 'Serraria', 323.2, 6239, 2.5),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301474, 'Sétimo Céu', 151.1, 1329, 10.91),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301475, 'Teresópolis', 386.1, 14707, 5.29),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301476, 'Tristeza', 260.8, 16692, 7.88),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301477, 'Vila Assunção', 135.9, 4418, 10.14),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301478, 'Vila Conceição', 37.4, 1349, 7.93),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 6', 'Centro-Sul e Sul', 4301479, 'Vila Nova', 1203.6, 32469, 3.14),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301480, 'Agronomia', 886.3, 2331, 2.59),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301481, 'Aparício Borges', 285.4, 19303, 2.11),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301482, 'Lomba do Pinheiro', 2975.1, 58106, 1.85),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301483, 'Partenon', 633.9, 48160, 4.01),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301484, 'Santo Antônio', 136.9, 13161, 4.72),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301485, 'São José', 304, 26522, 2.09),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 7', 'Lomba do Pinheiro e Partenon', 4301486, 'Vila João Pessoa', 112.2, 13041, 2.88),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301487, 'Belém Novo', 1486.4, 10100, 3.86),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301488, 'Boa Vista do Sul', 2436.6, 2309, 2.28),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301489, 'Chapéu do Sol', 598.7, 2913, 1.88),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301490, 'Extrema', 2155.9, 1981, 1.73),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301491, 'Lageado', 2276.9, 4481, 2.24),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301492, 'Lami', 1749.5, 4289, 1.87),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301493, 'Pitinga', 870.5, 4352, 1.92),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301494, 'Ponta Grossa', 1064.3, 8722, 2.27),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301495, 'Restinga', 2010.3, 53508, 1.76),
		(uuid_generate_v4(), 431490,'Porto Alegre', 'Região 8', 'Restinga e Extremo-Sul', 4301496, 'São Caetano', 830.1, 757, 2.37)

UPDATE cnes.estabelecimentos SET no_bairro='Aberta dos Morros' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ABERTA DOS MORROS';
UPDATE cnes.estabelecimentos SET no_bairro='Agronomia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AGRONOMIA';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ALTO PETROPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ALTO PTEROPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ALTO TERESOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Anchieta' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ANCHIETA';
UPDATE cnes.estabelecimentos SET no_bairro='Aparício Borges' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'APARICIO BORGES';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim São Pedro' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ASSIS BRASIL';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Assunção' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ASSUNCAO';
UPDATE cnes.estabelecimentos SET no_bairro='Auxiliadora' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AUXILIADIRA';
UPDATE cnes.estabelecimentos SET no_bairro='Auxiliadora' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AUXILIADOR';
UPDATE cnes.estabelecimentos SET no_bairro='Auxiliadora' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AUXILIADORA';
UPDATE cnes.estabelecimentos SET no_bairro='Auxiliadora' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AUXLIADORA';
UPDATE cnes.estabelecimentos SET no_bairro='Auxiliadora' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AUXULIADORA';
UPDATE cnes.estabelecimentos SET no_bairro='Azenha' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'AZENHA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Itu' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BAIRRO JARDIM ITU';
UPDATE cnes.estabelecimentos SET no_bairro='Tristeza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BAIRRO TRISTEZA';
UPDATE cnes.estabelecimentos SET no_bairro='Bela Vista' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BEL VISTA';
UPDATE cnes.estabelecimentos SET no_bairro='Bela Vista' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BELA VISTA';
UPDATE cnes.estabelecimentos SET no_bairro='Belém Novo' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BELEM NOVO';
UPDATE cnes.estabelecimentos SET no_bairro='Belém Velho' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BELEM VELHO';
UPDATE cnes.estabelecimentos SET no_bairro='Boa Vista' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BOA VISTA';
UPDATE cnes.estabelecimentos SET no_bairro='Bom Fim' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BOM DIM';
UPDATE cnes.estabelecimentos SET no_bairro='Bom Fim' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BOM FIM';
UPDATE cnes.estabelecimentos SET no_bairro='Bom Jesus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BOM JESUS';
UPDATE cnes.estabelecimentos SET no_bairro='Bom Fim' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BOMFIM';
UPDATE cnes.estabelecimentos SET no_bairro='Bom Fim' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'BONFIM';
UPDATE cnes.estabelecimentos SET no_bairro='Camaquã' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CAMAQUA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa ília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CAMINHO DO MEIO';
UPDATE cnes.estabelecimentos SET no_bairro='Campo Novo' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CAMPO NOVO';
UPDATE cnes.estabelecimentos SET no_bairro='Cascata' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CASCATA';
UPDATE cnes.estabelecimentos SET no_bairro='Cavalhada' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CAVALHADA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa ília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Agronomia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ER II';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Carvalho' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ER1JD CARVALHO';
UPDATE cnes.estabelecimentos SET no_bairro='Aparício Borges' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = ' APARICIO BORGES';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO HISRORICOI';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO HISTORIC';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO HISTORICO';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO HISTORIO';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRO HSITORICO';
UPDATE cnes.estabelecimentos SET no_bairro='Chácara das Pedras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CHACARA DAS PEDRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Chácara das Pedras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CHACARA PEDRA';
UPDATE cnes.estabelecimentos SET no_bairro='Chácara das Pedras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CHACARA PEDRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Chapéu do Sol' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CHAPEU DO SOL';
UPDATE cnes.estabelecimentos SET no_bairro='Cidade Baixa' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CIDADE BAIXA';
UPDATE cnes.estabelecimentos SET no_bairro='Cavalhada' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'COHAB';
UPDATE cnes.estabelecimentos SET no_bairro='Aparício Borges' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CORONEL APARICIO BOR';
UPDATE cnes.estabelecimentos SET no_bairro='Cristo Redentor' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CRISO REDENTOR';
UPDATE cnes.estabelecimentos SET no_bairro='Cristal' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CRISTAL';
UPDATE cnes.estabelecimentos SET no_bairro='Cristo Redentor' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CRISTO REDENDOR';
UPDATE cnes.estabelecimentos SET no_bairro='Cristo Redentor' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CRISTO REDENTOR';
UPDATE cnes.estabelecimentos SET no_bairro='Cristo Redentor' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CRISTOREDENTOR';
UPDATE cnes.estabelecimentos SET no_bairro='Espírito Santo' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ESPIRITO SANTO';
UPDATE cnes.estabelecimentos SET no_bairro='Farrapos' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'FARRAPOS';
UPDATE cnes.estabelecimentos SET no_bairro='Farroupilha' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'FARROUPILHA';
UPDATE cnes.estabelecimentos SET no_bairro='Farroupilha' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'FARROUPINHA';
UPDATE cnes.estabelecimentos SET no_bairro='Floresta' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'FLORESTA';
UPDATE cnes.estabelecimentos SET no_bairro='Glória' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'GLORIA';
UPDATE cnes.estabelecimentos SET no_bairro='Guarujá' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'GUARUJA';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIEGIENOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIGEANOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIGENOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIGIANOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIGIENOPLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Higienópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIGIENOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Hípica' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HIPICA';
UPDATE cnes.estabelecimentos SET no_bairro='Humaitá' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'HUMAITA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'IAPI';
UPDATE cnes.estabelecimentos SET no_bairro='Arquipélago' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ILHA DA PINTADA';
UPDATE cnes.estabelecimentos SET no_bairro='Arquipélago' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ILHA DO PAVAO';
UPDATE cnes.estabelecimentos SET no_bairro='Arquipélago' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'ILHA DOS MARINHEIROS';
UPDATE cnes.estabelecimentos SET no_bairro='Independência' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INDENPENDENCIA';
UPDATE cnes.estabelecimentos SET no_bairro='Independência' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INDEPDENDENCIA';
UPDATE cnes.estabelecimentos SET no_bairro='Independência' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INDEPENDEMCIA';
UPDATE cnes.estabelecimentos SET no_bairro='Independência' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INDEPENDENCIA';
UPDATE cnes.estabelecimentos SET no_bairro='Independência' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INDPENDENCIA';
UPDATE cnes.estabelecimentos SET no_bairro='Partenon' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'INTERCAP';
UPDATE cnes.estabelecimentos SET no_bairro='Ipanema' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'IPANEMA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Ipiranga' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'IPIRANGA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Leopoldina' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'J DONA LEOPOLDINA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Botânico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM BOTANICO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Carvalho' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM CARVALHO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim do Salso' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM DO SALSO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Europa' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM EUROPA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Floresta' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM FLORESTA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Ipiranga' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM IPIRANGA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Isabel' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM ISABEL';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Lindóia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM ITATI';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Itu' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM ITU';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Sabará' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM ITU SABARA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Sabará' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM ITUSABARA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Leopoldina' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM LEOPOLDINA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Lindóia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM LINDOIA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Itu' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM PLANALTO';
UPDATE cnes.estabelecimentos SET no_bairro='Lomba do Pinheiro' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM PROTASIO ALVE';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Sabará' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM SABARA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim do Salso' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM SALSO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim São Pedro' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIM SAO PEDRO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Sabará' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARDIN SABARA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim do Salso' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JARIDM DO SALSO';
UPDATE cnes.estabelecimentos SET no_bairro='Partenon' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JD BENTO GONCALVES';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Botânico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JD BOTANICO';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Leopoldina' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'JD LEOPOLDINA';
UPDATE cnes.estabelecimentos SET no_bairro='Lami' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'LAMI';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Leopoldina' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'LEOPOLDINA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Lindóia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'LINDOIA';
UPDATE cnes.estabelecimentos SET no_bairro='Lomba do Pinheiro' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'LOMBA DO PINHEIRO';
UPDATE cnes.estabelecimentos SET no_bairro='Menino Deus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MAENINO DEUS';
UPDATE cnes.estabelecimentos SET no_bairro='Mário Quintana' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MARIO QUINTANA';
UPDATE cnes.estabelecimentos SET no_bairro='Medianeira' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MEDIANEIRA';
UPDATE cnes.estabelecimentos SET no_bairro='Menino Deus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MEINO DEUS';
UPDATE cnes.estabelecimentos SET no_bairro='Menino Deus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MENINO';
UPDATE cnes.estabelecimentos SET no_bairro='Menino Deus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MENINO DEUS';
UPDATE cnes.estabelecimentos SET no_bairro='Menino Deus' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MENINOS DEUS';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MINHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MIONHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOIHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHIS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHO DE VENTOS';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS DE VENTOS';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS DE VENTRO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS DE VETO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS DEVENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOINHOS VENTOS';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MONHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Montserrat' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MONT SERRAT';
UPDATE cnes.estabelecimentos SET no_bairro='Montserrat' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MONTSERRAT';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MOOINHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Tereza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MORRO SANTA TEREZA';
UPDATE cnes.estabelecimentos SET no_bairro='Morro Santana' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MORRO SANTANA';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'MUINHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Navegantes' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'NAVEGANTES';
UPDATE cnes.estabelecimentos SET no_bairro='Nonoai' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'NONOAI';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'OINHOS DE VENTO';
UPDATE cnes.estabelecimentos SET no_bairro='Santa ília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'P 202';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PAETROPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Belém Velho' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PARQUE BELEM';
UPDATE cnes.estabelecimentos SET no_bairro='Parque Santa Fé' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PARQUE SANTA FE';
UPDATE cnes.estabelecimentos SET no_bairro='São Sebastião' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PARQUE SAO SEBASTIAO';
UPDATE cnes.estabelecimentos SET no_bairro='Partenon' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PARTENON';
UPDATE cnes.estabelecimentos SET no_bairro='Partenon' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PARTENOS';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO D AREA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO D AREIA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO DA AREIA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO DAREA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO DAREIA';
UPDATE cnes.estabelecimentos SET no_bairro='Passo das Pedras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSO DAS PEDRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PASSSO DA AREIA';
UPDATE cnes.estabelecimentos SET no_bairro='Pedra Redonda' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PEDRA REDONDA';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PETR0POLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PETROPLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Petrópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PETROPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Ponta Grossa' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PONTA GROSSA';
UPDATE cnes.estabelecimentos SET no_bairro='tro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PORTO ALEGRE' AND nu_endereco = '1781';
UPDATE cnes.estabelecimentos SET no_bairro='Moinhos de Vento' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PORTO ALEGRE' AND nu_endereco = '288';
UPDATE cnes.estabelecimentos SET no_bairro='São Sebastião' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PQ SAO SEBASTIAO';
UPDATE cnes.estabelecimentos SET no_bairro='Praia de Belas' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PRAIA DE BELAS';
UPDATE cnes.estabelecimentos SET no_bairro='Morro Santana' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PROTASIO ALVES' AND nu_endereco = '248';
UPDATE cnes.estabelecimentos SET no_bairro='Morro Santana' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PROTASIO ALVES' AND nu_endereco = '210';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Leopoldina' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'PROTASIO ALVES' AND nu_endereco = '130';
UPDATE cnes.estabelecimentos SET no_bairro='Restinga' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'RESTINGA';
UPDATE cnes.estabelecimentos SET no_bairro='Restinga' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'RESTINGA NOVA';
UPDATE cnes.estabelecimentos SET no_bairro='Rio Branco' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'RIO BRANCO';
UPDATE cnes.estabelecimentos SET no_bairro='Rubem Berta' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'RUBEM BERTA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa ília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANCA ILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa ília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA ILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Parque Santa Fé' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA FE';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Maria Goretti' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA MARIA GORETTI';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Tereza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA TERESA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Tereza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA TERESA PORTO A';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Tereza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA TEREZA';
UPDATE cnes.estabelecimentos SET no_bairro='Santana' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTANA';
UPDATE cnes.estabelecimentos SET no_bairro='Santo Antônio' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTO ANTONIO';
UPDATE cnes.estabelecimentos SET no_bairro='São Geraldo' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SAO GERALDO';
UPDATE cnes.estabelecimentos SET no_bairro='São João' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SAO JOAO';
UPDATE cnes.estabelecimentos SET no_bairro='São José' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SAO JOSE';
UPDATE cnes.estabelecimentos SET no_bairro='São Sebastião' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SAO SEBASTIAO';
UPDATE cnes.estabelecimentos SET no_bairro='Sarandi' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SARANDI';
UPDATE cnes.estabelecimentos SET no_bairro='Serraria' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SERRARIA';
UPDATE cnes.estabelecimentos SET no_bairro='Teresópolis' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TERESOPOLIS';
UPDATE cnes.estabelecimentos SET no_bairro='Três Figueiras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRES FIGEIRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Três Figueiras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRES FIGUEIRA';
UPDATE cnes.estabelecimentos SET no_bairro='Três Figueiras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRES FIGUEIRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Três Figueiras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRES FIQUEIRAS';
UPDATE cnes.estabelecimentos SET no_bairro='Três Figueiras' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRES FUGUEIRA';
UPDATE cnes.estabelecimentos SET no_bairro='Tristeza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRISITEZA';
UPDATE cnes.estabelecimentos SET no_bairro='Tristeza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRISTEZA';
UPDATE cnes.estabelecimentos SET no_bairro='Tristeza' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'TRSITEZA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Assunção' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA ASSUNCAO';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Conção' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA CONCAO';
UPDATE cnes.estabelecimentos SET no_bairro='Cristal' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA CRUZEIRO DO SUL';
UPDATE cnes.estabelecimentos SET no_bairro='Passo D’Areia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA IAPI';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Ipiranga' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA IPIRANGA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Jardim' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA JARDIM';
UPDATE cnes.estabelecimentos SET no_bairro='Vila João Pessoa' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA JOAO PESSOA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Nova' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA NNOVA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Nova' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA NOVA';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Conção' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA NOVA CONCAO';
UPDATE cnes.estabelecimentos SET no_bairro='Lomba do Pinheiro' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA VICOSA';
UPDATE cnes.estabelecimentos SET no_bairro='Jardim Carvalho' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CEFER1JD CARVALHO';
UPDATE cnes.estabelecimentos SET no_bairro='Aparício Borges' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CEL APARICIO BORGES';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Cecília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CECILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Agronomia' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CEFER II';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO HISRORICOI';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO HISTORIC';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO HISTORICO';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO HISTORIO';
UPDATE cnes.estabelecimentos SET no_bairro='Centro Histórico' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'CENTRO HSITORICO';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Cecília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANCA CECILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Cecília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'SANTA CECILIA';
UPDATE cnes.estabelecimentos SET no_bairro='Santa Cecília' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'Santa ília';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Conceição' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA CONCEICAO';
UPDATE cnes.estabelecimentos SET no_bairro='Vila Conceição' WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'VILA NOVA CONCEICAO';

DELETE FROM cnes.estabelecimentos WHERE co_unidade IS NOT NULL AND co_unidade LIKE '431490%' AND no_bairro = 'IGARA';

INSERT INTO bi.dim_tempos(
	id, ano, mes)
	VALUES (uuid_generate_v4(), 2024, 3);