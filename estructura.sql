-- =====================================================================
--  PROYECTO CAPSTONE - Análisis Exploratorio de Datos (EDA) en PostgreSQL
--  Archivo : estructura.sql
--  Autora  : Yarovid Matamoros
--  Motor   : PostgreSQL 13+ (probado en PostgreSQL 16)
--
--  Contexto: "SeguriTech" (empresa ficticia) distribuye equipamiento de
--  seguridad electrónica (cámaras, grabadores, alarmas, control de acceso,
--  redes) a particulares, municipios, barrios cerrados y empresas.
--  El sistema de ventas exporta los datos en planillas "sucias"; este
--  script los carga tal cual llegan (capa staging) y luego los limpia
--  y tipa correctamente en las tablas finales que usa analisis.sql.
--
--  ORDEN DE EJECUCIÓN
--    PASO 1 (una sola vez, conectada a la base "postgres"):
--        CREATE DATABASE capstone_project;
--    PASO 2: conectarse a capstone_project y ejecutar ESTE archivo completo.
--        psql:    psql -d capstone_project -f estructura.sql
--        pgAdmin: Query Tool sobre capstone_project -> abrir archivo -> F5
--
--  El script es re-ejecutable: borra y recrea sus objetos.
-- =====================================================================


-- Fijamos el estilo de fecha para que la conversión de textos sea predecible.
SET datestyle = 'ISO, DMY';

DROP TABLE IF EXISTS pedidos       CASCADE;
DROP TABLE IF EXISTS productos     CASCADE;
DROP TABLE IF EXISTS clientes      CASCADE;
DROP TABLE IF EXISTS stg_pedidos   CASCADE;
DROP TABLE IF EXISTS stg_productos CASCADE;
DROP TABLE IF EXISTS stg_clientes  CASCADE;

-- =====================================================================
-- ETAPA 1. CAPA STAGING (datos crudos)
-- Todas las columnas son TEXT a propósito: así se reciben las planillas
-- exportadas y no queremos que la carga falle por un dato mal escrito.
-- La validación de tipos ocurre recién en la etapa de limpieza.
-- =====================================================================
CREATE TABLE stg_clientes (
    cliente_id  TEXT,
    nombre      TEXT,
    email       TEXT,
    ciudad      TEXT,
    fecha_alta  TEXT          -- llega en formatos mixtos: AAAA-MM-DD y DD/MM/AAAA
);

CREATE TABLE stg_productos (
    producto_id  TEXT,
    nombre       TEXT,
    categoria    TEXT,        -- misma categoría escrita de distintas formas
    precio_lista TEXT         -- nulos, vacíos y coma como separador decimal
);

CREATE TABLE stg_pedidos (
    pedido_id       TEXT,
    cliente_id      TEXT,
    producto_id     TEXT,
    fecha_pedido    TEXT,     -- formatos mixtos y algunos nulos
    cantidad        TEXT,     -- algunos nulos
    precio_unitario TEXT,     -- nulos, vacíos y coma decimal
    estado          TEXT      -- mayúsculas/minúsculas y espacios inconsistentes
);

-- ---------------------------------------------------------------------
-- Carga de datos crudos (121 filas de ventas del año 2025, incluida una fila duplicada a propósito).
-- ---------------------------------------------------------------------
INSERT INTO stg_clientes (cliente_id, nombre, email, ciudad, fecha_alta) VALUES
  ('1', '  ana gómez', 'ana.gomez@mail.com', 'CABA', '2024-03-15'),
  ('2', 'LUCAS PEREYRA', 'lpereyra@mail.com', 'caba ', '10/05/2024'),
  ('3', 'Martina Ruiz', NULL, 'Córdoba', '2024-06-01'),
  ('4', 'Diego Fernández', 'dfernandez@mail.com', 'Rosario', '2024-01-20'),
  ('5', 'sofía lópez', 'sofia.lopez@mail.com', 'cordoba', '15/08/2024'),
  ('6', 'Javier Molina', 'jmolina@mail.com', 'Mendoza', '2024-02-11'),
  ('7', 'Valentina Castro', '', 'La Plata', '2024-09-30'),
  ('8', 'Municipalidad de Tigre', 'compras@tigre-demo.gob', 'Tigre', '2023-11-05'),
  ('9', 'Municipalidad de Pilar', 'compras@pilar-demo.gob', 'Pilar', '2024-04-18'),
  ('10', 'Barrio Cerrado Los Robles', 'admin@losrobles-demo.com', 'Pilar ', '2024-07-07'),
  ('11', 'Carlos Benítez', 'cbenitez@mail.com', 'Rosario', '03/12/2024'),
  ('12', 'Hotel Plaza Sur', 'compras@plazasur-demo.com', 'Mendoza', '2024-05-22'),
  ('13', 'Lucía Romero', NULL, 'CABA', '2025-01-09'),
  ('14', 'Colegio San Martín', 'admin@csm-demo.edu', 'La Plata', '2024-10-14'),
  ('15', 'Pedro Acosta', 'pacosta@mail.com', 'Córdoba ', '2025-02-02');

INSERT INTO stg_productos (producto_id, nombre, categoria, precio_lista) VALUES
  ('101', 'Cámara domo IP 4MP', 'Cámaras', '120.00'),
  ('102', 'Cámara bullet IP 8MP', 'camaras ', '185,50'),
  ('103', 'Cámara PTZ 25x', 'CÁMARAS', '890.00'),
  ('104', 'Cámara LPR lectura de patentes', 'Cámaras', NULL),
  ('105', 'NVR 16 canales', 'Grabadores', '410.00'),
  ('106', 'NVR 32 canales', 'grabadores', '720.00'),
  ('107', 'Disco rígido 8TB vigilancia', 'Almacenamiento', '210.00'),
  ('108', 'Panel de alarma 8 zonas', 'Alarmas', '150.00'),
  ('109', 'Sensor PIR inalámbrico', 'alarmas', '35,00'),
  ('110', 'Sirena exterior', 'Alarmas ', ''),
  ('111', 'Lector biométrico de acceso', 'Control de Acceso', '260.00'),
  ('112', 'Cerradura electromagnética', 'control de acceso', '95.00'),
  ('113', 'Switch PoE 16 puertos', 'Redes', '330.00'),
  ('114', 'Bobina cable UTP Cat6 305m', 'redes', '140,00'),
  ('115', 'Fuente de alimentación 12V 10A', 'Accesorios', '45.00'),
  ('116', 'Soporte de pared para domo', 'accesorios', '12.00');

INSERT INTO stg_pedidos (pedido_id, cliente_id, producto_id, fecha_pedido, cantidad, precio_unitario, estado) VALUES
  ('1001', '1', '101', '2025-01-04', '1', '120.00', 'entregado'),
  ('1002', '10', '116', '2025-01-07', '26', '10.80', 'ENTREGADO '),
  ('1003', '11', '102', '2025-01-18', '4', '185,50', 'entregado'),
  ('1004', '10', '108', '21/01/2025', '9', '150.00', 'entregado'),
  ('1005', '3', '103', '2025-01-28', '1', NULL, 'entregado'),
  ('1006', '5', '108', '2025-02-09', NULL, '150.00', 'cancelado'),
  ('1007', '8', '106', '2025-02-10', '2', '', 'entregado'),
  ('1008', '3', '108', '2025-02-24', '4', '150.00', 'entregado'),
  ('1009', '9', '112', '2025-02-27', '4', '95.00', 'entregado'),
  ('1010', '1', '115', '2025-03-02', '1', '45.00', 'entregado'),
  ('1011', '4', '108', '04/03/2025', '1', '150.00', 'entregado'),
  ('1012', '10', '114', '2025-03-17', '10', '126,00', 'ENTREGADO '),
  ('1013', '13', '114', '2025-03-23', '4', '140.00', 'entregado'),
  ('1014', '12', '105', '2025-03-24', '22', '369.00', 'entregado'),
  ('1015', '6', '107', '2025-03-26', '3', '210.00', 'entregado'),
  ('1016', '10', '102', '2025-03-26', '30', NULL, 'entregado'),
  ('1017', '14', '105', '2025-03-28', '17', '369.00', 'entregado'),
  ('1018', '9', '115', NULL, '9', '45.00', 'entregado'),
  ('1019', '10', '114', '2025-04-11', '13', '126.00', 'entregado'),
  ('1020', '1', '108', '2025-04-11', '4', '', 'entregado'),
  ('1021', '4', '101', '2025-04-17', '2', '120,00', 'cancelado'),
  ('1022', '14', '109', '2025-05-12', '14', '31.50', 'ENTREGADO '),
  ('1023', '6', '108', '2025-05-13', '2', '150.00', 'cancelado'),
  ('1024', '11', '115', '2025-05-14', '3', '45.00', 'entregado'),
  ('1025', '9', '101', '15/05/2025', '24', '108.00', 'entregado'),
  ('1026', '9', '109', '2025-05-16', '7', '35.00', 'entregado'),
  ('1027', '9', '101', '2025-05-18', '21', NULL, 'entregado'),
  ('1028', '9', '102', '2025-05-19', '22', '166.95', 'entregado'),
  ('1029', '8', '111', '2025-05-19', NULL, '260.00', 'entregado'),
  ('1030', '9', '115', '2025-05-25', '18', '40,50', 'entregado'),
  ('1031', '4', '110', '2025-05-26', '3', '60.00', 'entregado'),
  ('1032', '10', '114', '06/06/2025', '10', '126.00', 'ENTREGADO '),
  ('1033', '9', '105', '2025-06-08', '28', '', 'entregado'),
  ('1034', '10', '105', '2025-06-13', '22', '369.00', 'entregado'),
  ('1035', '5', '114', '2025-06-15', '4', '140.00', 'entregado'),
  ('1036', '9', '115', '2025-06-17', '29', '40.50', 'entregado'),
  ('1037', '13', '109', '2025-06-19', '4', '35.00', 'entregado'),
  ('1038', '9', '101', '2025-06-24', '12', NULL, 'entregado'),
  ('1039', '10', '115', '27/06/2025', '15', '40,50', 'entregado'),
  ('1040', '12', '114', '2025-07-01', '5', '140.00', 'entregado'),
  ('1041', '3', '108', '2025-07-02', '1', '150.00', 'entregado'),
  ('1042', '14', '101', '2025-07-18', '30', '108.00', 'ENTREGADO '),
  ('1043', '14', '107', '2025-07-20', '29', '189.00', 'entregado'),
  ('1044', '14', '101', '2025-07-22', '13', '108.00', 'entregado'),
  ('1045', '9', '114', '2025-07-25', '24', '126.00', 'entregado'),
  ('1046', '11', '101', '10/08/2025', '3', '', 'entregado'),
  ('1047', '4', '105', '2025-08-11', '3', '410.00', 'entregado'),
  ('1048', '14', '101', '2025-08-17', '11', '108,00', 'cancelado'),
  ('1049', '4', '108', '2025-08-17', '2', NULL, 'entregado'),
  ('1050', '5', '114', '2025-08-18', '3', '140.00', 'entregado'),
  ('1051', '2', '101', '2025-08-20', '3', '120.00', 'entregado'),
  ('1052', '1', '104', '2025-08-20', NULL, '1450.00', 'ENTREGADO '),
  ('1053', '4', '101', '22/08/2025', '4', '120.00', 'entregado'),
  ('1054', '5', '107', '2025-08-27', '4', '210.00', 'entregado'),
  ('1055', '2', '107', '2025-08-28', '1', '210.00', 'entregado'),
  ('1056', '2', '104', '2025-09-03', '1', '1450.00', 'cancelado'),
  ('1057', '14', '101', '2025-09-03', '30', '108,00', 'entregado'),
  ('1058', '9', '102', '2025-09-04', '13', '166.95', 'entregado'),
  ('1059', '8', '108', '2025-09-05', '7', '', 'entregado'),
  ('1060', '10', '108', '07/09/2025', '22', NULL, 'entregado'),
  ('1061', '8', '113', '2025-09-07', '9', '330.00', 'entregado'),
  ('1062', '8', '101', '2025-09-07', '4', '120.00', 'ENTREGADO '),
  ('1063', '8', '102', '2025-09-08', '14', '166.95', 'cancelado'),
  ('1064', '11', '108', '2025-09-12', '1', '150.00', 'entregado'),
  ('1065', '9', '102', NULL, '23', '166.95', 'entregado'),
  ('1066', '3', '108', '2025-09-18', '2', '150,00', 'entregado'),
  ('1067', '11', '102', '25/09/2025', '3', '185.50', 'entregado'),
  ('1068', '5', '101', '2025-09-26', '2', '120.00', 'entregado'),
  ('1069', '12', '115', '2025-09-28', '20', '40.50', 'cancelado'),
  ('1070', '9', '107', '2025-10-02', '16', '189.00', 'entregado'),
  ('1071', '14', '107', '2025-10-05', '21', NULL, 'entregado'),
  ('1072', '10', '108', '2025-10-07', '8', '', 'ENTREGADO '),
  ('1073', '1', '111', '2025-10-11', '1', '260.00', 'entregado'),
  ('1074', '9', '107', '12/10/2025', '9', '210.00', 'entregado'),
  ('1075', '9', '110', '2025-10-14', NULL, '54,00', 'entregado'),
  ('1076', '9', '114', '2025-10-14', '15', '126.00', 'entregado'),
  ('1077', '13', '101', '2025-10-14', '2', '120.00', 'entregado'),
  ('1078', '12', '111', '2025-10-17', '25', '234.00', 'entregado'),
  ('1079', '8', '114', '2025-10-19', '13', '126.00', 'entregado'),
  ('1080', '8', '113', '2025-10-22', '14', '297.00', 'entregado'),
  ('1081', '15', '108', '23/10/2025', '4', '150.00', 'entregado'),
  ('1082', '14', '102', '2025-10-23', '13', NULL, 'ENTREGADO '),
  ('1083', '8', '102', '2025-11-01', '5', '185.50', 'entregado'),
  ('1084', '4', '114', '2025-11-02', '4', '140,00', 'entregado'),
  ('1085', '9', '114', '2025-11-06', '4', '', 'entregado'),
  ('1086', '9', '115', '2025-11-11', '18', '40.50', 'entregado'),
  ('1087', '2', '103', '2025-11-11', '1', '890.00', 'entregado'),
  ('1088', '12', '111', '11/11/2025', '28', '234.00', 'entregado'),
  ('1089', '8', '102', '2025-11-13', '4', '185.50', 'cancelado'),
  ('1090', '5', '107', '2025-11-14', '3', '210.00', 'entregado'),
  ('1091', '8', '105', '2025-11-15', '10', '369.00', 'entregado'),
  ('1092', '13', '115', '2025-11-16', '3', '45.00', 'CANCELADO '),
  ('1093', '14', '115', '2025-11-16', '6', NULL, 'entregado'),
  ('1094', '2', '110', '2025-11-17', '3', '60.00', 'entregado'),
  ('1095', '8', '108', '19/11/2025', '19', '135.00', 'entregado'),
  ('1096', '10', '115', '2025-11-19', '13', '40.50', 'entregado'),
  ('1097', '4', '105', '2025-11-19', '3', '410.00', 'entregado'),
  ('1098', '8', '101', '2025-11-21', NULL, '', 'cancelado'),
  ('1099', '3', '111', '2025-11-22', '2', '260.00', 'entregado'),
  ('1100', '3', '110', '2025-11-24', '2', '60.00', 'entregado'),
  ('1101', '12', '109', '2025-11-27', '5', '35.00', 'cancelado'),
  ('1102', '1', '114', '27/11/2025', '3', '140,00', 'ENTREGADO '),
  ('1103', '14', '115', '2025-11-27', '25', '40.50', 'entregado'),
  ('1104', '12', '107', '2025-11-28', '23', NULL, 'entregado'),
  ('1105', '9', '113', '2025-11-28', '20', '297.00', 'entregado'),
  ('1106', '4', '112', '2025-12-05', '3', '95.00', 'cancelado'),
  ('1107', '14', '115', '2025-12-06', '27', '40.50', 'entregado'),
  ('1108', '10', '115', '2025-12-09', '21', '40.50', 'entregado'),
  ('1109', '9', '113', '09/12/2025', '29', '297.00', 'entregado'),
  ('1110', '9', '115', '2025-12-10', '11', '40.50', 'entregado'),
  ('1111', '10', '109', '2025-12-11', '23', '', 'entregado'),
  ('1112', '9', '109', '2025-12-11', '4', '35.00', 'ENTREGADO '),
  ('1113', '12', '102', '2025-12-15', '24', '166.95', 'entregado'),
  ('1114', '9', '115', '2025-12-17', '13', '40.50', 'entregado'),
  ('1115', '8', '115', '2025-12-22', '15', NULL, 'entregado'),
  ('1116', '12', '101', '23/12/2025', '15', '108.00', 'entregado'),
  ('1117', '15', '107', '2025-12-24', '1', '210.00', 'entregado'),
  ('1118', '4', '115', '2025-12-26', '4', '45.00', 'cancelado'),
  ('1119', '14', '106', '2025-12-26', '2', '720.00', 'entregado'),
  ('1120', '3', '114', '2025-12-27', '4', '140,00', 'entregado'),
  ('1031', '4', '110', '2025-05-26', '3', '60.00', 'entregado');

-- =====================================================================
-- ETAPA 2. MODELO FINAL (tipos de datos correctos + integridad)
--   * Montos en NUMERIC(12,2): nunca FLOAT para dinero (evita redondeos).
--   * Fechas en DATE para poder usar funciones de fecha (DATE_TRUNC, etc.).
--   * PK / FK garantizan que cada pedido apunte a un cliente y producto reales.
--   * CHECK impide cantidades o precios negativos.
-- =====================================================================
CREATE TABLE clientes (
    cliente_id   INTEGER      PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    email        VARCHAR(150),                 -- opcional: puede quedar NULL
    ciudad       VARCHAR(60)  NOT NULL,
    tipo_cliente VARCHAR(20)  NOT NULL,        -- Particular / Institucional
    fecha_alta   DATE         NOT NULL
);

CREATE TABLE productos (
    producto_id  INTEGER       PRIMARY KEY,
    nombre       VARCHAR(100)  NOT NULL,
    categoria    VARCHAR(50)   NOT NULL,
    precio_lista NUMERIC(12,2) NOT NULL CHECK (precio_lista >= 0),
    precio_imputado BOOLEAN    NOT NULL DEFAULT FALSE  -- trazabilidad de la limpieza
);

CREATE TABLE pedidos (
    pedido_id       INTEGER       PRIMARY KEY,
    cliente_id      INTEGER       NOT NULL REFERENCES clientes(cliente_id),
    producto_id     INTEGER       NOT NULL REFERENCES productos(producto_id),
    fecha_pedido    DATE          NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    estado          VARCHAR(20)   NOT NULL,
    -- Columna calculada: evita recalcular el importe en cada consulta.
    importe         NUMERIC(14,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

-- Índices solo en las columnas que se usan en JOIN / WHERE del análisis
-- (indexar todo ralentiza la carga y no aporta).
CREATE INDEX idx_pedidos_cliente  ON pedidos (cliente_id);
CREATE INDEX idx_pedidos_producto ON pedidos (producto_id);
CREATE INDEX idx_pedidos_fecha    ON pedidos (fecha_pedido);

-- =====================================================================
-- ETAPA 3. LIMPIEZA Y TRANSFORMACIÓN (staging -> modelo final)
-- =====================================================================

-- Función auxiliar: convierte textos de fecha en formato mixto a DATE.
-- Si el formato no se reconoce devuelve NULL en lugar de romper la carga.
CREATE OR REPLACE FUNCTION fn_texto_a_fecha(p_txt TEXT)
RETURNS DATE
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN TRIM(p_txt) ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(TRIM(p_txt), 'YYYY-MM-DD')
        WHEN TRIM(p_txt) ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(TRIM(p_txt), 'DD/MM/YYYY')
        ELSE NULL
    END;
$$;

-- Función auxiliar: convierte montos en texto ("185,50", "", NULL) a NUMERIC.
-- NULLIF transforma el texto vacío en NULL para que luego COALESCE lo trate
-- igual que un nulo real (un '' no es un precio válido).
CREATE OR REPLACE FUNCTION fn_texto_a_monto(p_txt TEXT)
RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT REPLACE(NULLIF(TRIM(p_txt), ''), ',', '.')::NUMERIC;
$$;

-- 3.1 CLIENTES ---------------------------------------------------------
-- * Nombres: se quitan espacios; solo los escritos TODO en mayúsculas o TODO
--   en minúsculas se pasan a INITCAP. Aplicarlo a todos arruinaría nombres
--   bien escritos ("Municipalidad de Pilar" -> "Municipalidad De Pilar").
-- * Ciudad: "caba ", "cordoba", "Córdoba " se normalizan a un único valor,
--   de lo contrario el análisis por ciudad partiría una ciudad en varias.
-- * Email vacío ('') se convierte en NULL: es un dato desconocido, no un email.
-- * tipo_cliente se deriva con CASE para segmentar B2B vs. particulares.
INSERT INTO clientes (cliente_id, nombre, email, ciudad, tipo_cliente, fecha_alta)
SELECT
    cliente_id::INTEGER,
    CASE
        WHEN TRIM(nombre) IN (UPPER(TRIM(nombre)), LOWER(TRIM(nombre)))
            THEN INITCAP(TRIM(nombre))
        ELSE TRIM(nombre)
    END,
    NULLIF(TRIM(email), ''),
    CASE LOWER(TRIM(ciudad))
        WHEN 'caba'    THEN 'CABA'
        WHEN 'cordoba' THEN 'Córdoba'
        WHEN 'córdoba' THEN 'Córdoba'
        ELSE INITCAP(TRIM(ciudad))
    END,
    CASE
        WHEN nombre ILIKE ANY (ARRAY['%municipalidad%', '%barrio%', '%hotel%', '%colegio%'])
            THEN 'Institucional'
        ELSE 'Particular'
    END,
    fn_texto_a_fecha(fecha_alta)
FROM stg_clientes;

-- 3.2 PRODUCTOS --------------------------------------------------------
-- * Categoría: se normaliza quitando espacios, mayúsculas y tildes
--   ("CÁMARAS", "camaras ", "Cámaras" -> "Cámaras").
-- * Precio de lista nulo o vacío: es una columna CRÍTICA (sin precio no hay
--   facturación), por eso se imputa con COALESCE en este orden:
--     1) precio de lista informado;
--     2) precio promedio al que efectivamente se vendió ese producto;
--     3) precio promedio de lista de su categoría.
--   Se marca precio_imputado = TRUE para que el dato sea auditable.
WITH prod AS (
    SELECT
        producto_id::INTEGER                      AS producto_id,
        TRIM(nombre)                              AS nombre,
        CASE TRANSLATE(LOWER(TRIM(categoria)), 'áéíóú', 'aeiou')
            WHEN 'camaras'           THEN 'Cámaras'
            WHEN 'grabadores'        THEN 'Grabadores'
            WHEN 'almacenamiento'    THEN 'Almacenamiento'
            WHEN 'alarmas'           THEN 'Alarmas'
            WHEN 'control de acceso' THEN 'Control de Acceso'
            WHEN 'redes'             THEN 'Redes'
            WHEN 'accesorios'        THEN 'Accesorios'
            ELSE 'Sin categoría'
        END                                       AS categoria,
        fn_texto_a_monto(precio_lista)            AS precio_lista
    FROM stg_productos
),
precio_vendido AS (
    -- Precio real de venta por producto (solo ventas sin descuento por volumen
    -- ni datos faltantes, para no subestimar el precio de lista).
    SELECT producto_id::INTEGER AS producto_id,
           ROUND(AVG(fn_texto_a_monto(precio_unitario)), 2) AS precio_prom
    FROM stg_pedidos
    WHERE fn_texto_a_monto(precio_unitario) IS NOT NULL
      AND COALESCE(NULLIF(TRIM(cantidad), '')::INTEGER, 1) < 10
    GROUP BY producto_id::INTEGER
),
precio_categoria AS (
    SELECT categoria, ROUND(AVG(precio_lista), 2) AS precio_cat
    FROM prod
    GROUP BY categoria
)
INSERT INTO productos (producto_id, nombre, categoria, precio_lista, precio_imputado)
SELECT
    p.producto_id,
    p.nombre,
    p.categoria,
    COALESCE(p.precio_lista, pv.precio_prom, pc.precio_cat, 0),
    (p.precio_lista IS NULL)
FROM prod p
LEFT JOIN precio_vendido   pv ON pv.producto_id = p.producto_id
LEFT JOIN precio_categoria pc ON pc.categoria   = p.categoria;

-- 3.3 PEDIDOS ----------------------------------------------------------
-- Decisiones sobre datos faltantes (regla de oro: explicitarlas):
-- * Duplicados: la exportación cargó una venta dos veces; DISTINCT ON
--   conserva una sola fila por pedido_id para no inflar la facturación.
-- * Cantidad nula: se asume 1 unidad con COALESCE (todo pedido registrado
--   tiene al menos una unidad).
-- * Precio unitario nulo o vacío: se usa el precio de lista del producto
--   con COALESCE (supuesto conservador: venta sin descuento).
-- * Fecha nula: NO se puede imputar sin inventar estacionalidad, por eso
--   esos pedidos se excluyen y se reportan en la verificación final.
-- * Estado: se normaliza ("ENTREGADO " -> "entregado").
INSERT INTO pedidos (pedido_id, cliente_id, producto_id, fecha_pedido,
                     cantidad, precio_unitario, estado)
SELECT DISTINCT ON (sp.pedido_id::INTEGER)
    sp.pedido_id::INTEGER,
    sp.cliente_id::INTEGER,
    sp.producto_id::INTEGER,
    fn_texto_a_fecha(sp.fecha_pedido),
    COALESCE(NULLIF(TRIM(sp.cantidad), '')::INTEGER, 1),
    COALESCE(fn_texto_a_monto(sp.precio_unitario), pr.precio_lista),
    LOWER(TRIM(sp.estado))
FROM stg_pedidos sp
JOIN productos pr ON pr.producto_id = sp.producto_id::INTEGER
WHERE fn_texto_a_fecha(sp.fecha_pedido) IS NOT NULL
ORDER BY sp.pedido_id::INTEGER;

-- =====================================================================
-- ETAPA 4. VERIFICACIÓN DE LA CARGA
-- Comparar conteos antes y después detecta pérdidas o duplicaciones.
-- =====================================================================
SELECT 'stg_pedidos (crudo)'          AS tabla, COUNT(*) AS filas FROM stg_pedidos
UNION ALL
SELECT 'pedidos (limpio)',                     COUNT(*)          FROM pedidos
UNION ALL
SELECT 'descartados por fecha nula',           COUNT(*)          FROM stg_pedidos
       WHERE fn_texto_a_fecha(fecha_pedido) IS NULL
UNION ALL
SELECT 'duplicados eliminados',
       (SELECT COUNT(*) - COUNT(DISTINCT pedido_id) FROM stg_pedidos)
UNION ALL
SELECT 'clientes',                             COUNT(*)          FROM clientes
UNION ALL
SELECT 'productos',                            COUNT(*)          FROM productos;
