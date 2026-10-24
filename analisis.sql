-- =====================================================================
--  PROYECTO CAPSTONE - Análisis Exploratorio de Datos (EDA) en PostgreSQL
--  Archivo : analisis.sql
--  Autora  : Yarovid Matamoros
--  Requisito previo: haber ejecutado estructura.sql en capstone_project.
--
--  Regla de negocio común a todas las consultas de ventas:
--  solo cuentan los pedidos con estado 'entregado'. Un pedido cancelado
--  no generó ingreso y sumarlo inflaría la facturación.
-- =====================================================================


-- =====================================================================
-- 0. CONTROL DE CALIDAD (antes de analizar)
-- Confirmamos que la limpieza dejó sin nulos las columnas críticas.
-- Si algún valor fuera > 0, los resultados posteriores no serían confiables.
-- =====================================================================
SELECT
    COUNT(*)                                      AS total_pedidos,
    COUNT(*) FILTER (WHERE fecha_pedido    IS NULL) AS fechas_nulas,
    COUNT(*) FILTER (WHERE precio_unitario IS NULL) AS precios_nulos,
    COUNT(*) FILTER (WHERE cantidad        IS NULL) AS cantidades_nulas,
    COUNT(*) FILTER (WHERE estado = 'cancelado')    AS pedidos_cancelados
FROM pedidos;

-- Cuántos datos críticos llegaron vacíos en el origen: dimensiona cuánto
-- del resultado depende de valores imputados con COALESCE.
SELECT
    COUNT(*) FILTER (WHERE NULLIF(TRIM(precio_unitario), '') IS NULL) AS precios_faltantes_origen,
    COUNT(*) FILTER (WHERE NULLIF(TRIM(cantidad), '')        IS NULL) AS cantidades_faltantes_origen,
    COUNT(*) FILTER (WHERE fecha_pedido IS NULL)                      AS fechas_faltantes_origen
FROM stg_pedidos;

-- Productos con precio de lista imputado (transparencia para el lector).
SELECT producto_id, nombre, categoria, precio_lista
FROM productos
WHERE precio_imputado;


-- =====================================================================
-- PREGUNTA 1. ¿Quiénes son nuestros 5 clientes más valiosos?
-- Técnica: JOIN + GROUP BY + SUM.
-- Por qué: concentrar la atención comercial (descuentos, soporte, renovación
-- de contratos) en quienes sostienen la facturación.
-- =====================================================================
SELECT
    c.cliente_id,
    c.nombre,
    c.tipo_cliente,
    c.ciudad,
    COUNT(p.pedido_id)            AS pedidos,
    SUM(p.importe)                AS gasto_total_usd,
    -- Participación sobre la facturación total: muestra la dependencia
    -- del negocio respecto de cada cliente.
    ROUND(100.0 * SUM(p.importe) / SUM(SUM(p.importe)) OVER (), 1) AS pct_facturacion
FROM clientes c
JOIN pedidos  p ON p.cliente_id = c.cliente_id
WHERE p.estado = 'entregado'
GROUP BY c.cliente_id, c.nombre, c.tipo_cliente, c.ciudad
ORDER BY gasto_total_usd DESC
LIMIT 5;


-- =====================================================================
-- PREGUNTA 2. ¿Cómo evolucionan las ventas mes a mes?
-- Técnica: funciones de fecha (DATE_TRUNC, TO_CHAR) + CTE + Window
-- Functions (SUM acumulado y LAG).
-- Por qué: detectar estacionalidad para planificar stock y personal técnico.
-- =====================================================================
WITH ventas_mes AS (
    SELECT
        DATE_TRUNC('month', fecha_pedido)::DATE AS mes,
        COUNT(*)                                AS pedidos,
        SUM(importe)                            AS ventas_usd
    FROM pedidos
    WHERE estado = 'entregado'
    GROUP BY DATE_TRUNC('month', fecha_pedido)
)
SELECT
    TO_CHAR(mes, 'YYYY-MM')                              AS mes,
    pedidos,
    ventas_usd,
    SUM(ventas_usd) OVER (ORDER BY mes)                  AS ventas_acumuladas_usd,
    -- Variación contra el mes anterior. NULLIF evita la división por cero;
    -- el primer mes queda NULL porque no tiene mes previo con qué comparar.
    ROUND(100.0 * (ventas_usd - LAG(ventas_usd) OVER (ORDER BY mes))
          / NULLIF(LAG(ventas_usd) OVER (ORDER BY mes), 0), 1) AS variacion_pct
FROM ventas_mes
ORDER BY mes;

-- Resumen por trimestre para la lectura directiva.
SELECT
    'T' || EXTRACT(QUARTER FROM fecha_pedido) AS trimestre,
    SUM(importe)                              AS ventas_usd,
    ROUND(100.0 * SUM(importe) / SUM(SUM(importe)) OVER (), 1) AS pct_anual
FROM pedidos
WHERE estado = 'entregado'
GROUP BY EXTRACT(QUARTER FROM fecha_pedido)
ORDER BY trimestre;


-- =====================================================================
-- PREGUNTA 3. ¿Cuáles son los 3 productos menos vendidos?
-- Técnica: LEFT JOIN + COALESCE.
-- Por qué LEFT JOIN: un producto que NUNCA se vendió no aparece en pedidos;
-- con un JOIN común desaparecería del ranking justamente el peor caso.
-- COALESCE convierte esa ausencia (NULL) en 0 unidades para poder ordenar.
-- =====================================================================
SELECT
    pr.producto_id,
    pr.nombre,
    pr.categoria,
    COALESCE(SUM(p.cantidad), 0) AS unidades_vendidas,
    COALESCE(SUM(p.importe), 0)  AS ventas_usd
FROM productos pr
LEFT JOIN pedidos p
       ON p.producto_id = pr.producto_id
      AND p.estado = 'entregado'   -- el filtro va en el ON para no anular el LEFT JOIN
GROUP BY pr.producto_id, pr.nombre, pr.categoria
ORDER BY unidades_vendidas ASC, ventas_usd ASC
LIMIT 3;


-- =====================================================================
-- PREGUNTA 4. Ranking de pedidos dentro de cada categoría
-- Técnica: Window Function RANK() con PARTITION BY.
-- Por qué: identificar las operaciones "ancla" de cada línea de producto
-- (las que justifican mantener stock y proveedor) sin perder el detalle.
-- Se muestran los 3 mayores pedidos por categoría.
-- =====================================================================
WITH ranking AS (
    SELECT
        pr.categoria,
        p.pedido_id,
        c.nombre                AS cliente,
        pr.nombre               AS producto,
        p.fecha_pedido,
        p.importe,
        RANK() OVER (PARTITION BY pr.categoria ORDER BY p.importe DESC) AS ranking
    FROM pedidos   p
    JOIN productos pr ON pr.producto_id = p.producto_id
    JOIN clientes  c  ON c.cliente_id   = p.cliente_id
    WHERE p.estado = 'entregado'
)
SELECT categoria, ranking, pedido_id, cliente, producto, fecha_pedido, importe
FROM ranking
WHERE ranking <= 3
ORDER BY categoria, ranking;

-- Complemento: peso de cada categoría en la facturación y su posición.
SELECT
    pr.categoria,
    SUM(p.importe)                                   AS ventas_usd,
    RANK() OVER (ORDER BY SUM(p.importe) DESC)       AS ranking_categoria,
    ROUND(100.0 * SUM(p.importe) / SUM(SUM(p.importe)) OVER (), 1) AS pct_facturacion
FROM pedidos   p
JOIN productos pr ON pr.producto_id = p.producto_id
WHERE p.estado = 'entregado'
GROUP BY pr.categoria
ORDER BY ventas_usd DESC;


-- =====================================================================
-- PREGUNTA 5. ¿Qué segmento de cliente sostiene el negocio?
-- Técnica: CASE para segmentar + GROUP BY.
-- Por qué: definir si la estrategia comercial debe orientarse a cuentas
-- institucionales (municipios, barrios, empresas) o a particulares.
-- =====================================================================
SELECT
    c.tipo_cliente,
    COUNT(DISTINCT c.cliente_id)                         AS clientes,
    COUNT(p.pedido_id)                                   AS pedidos,
    SUM(p.importe)                                       AS ventas_usd,
    ROUND(AVG(p.importe), 2)                             AS ticket_promedio_usd,
    ROUND(100.0 * SUM(p.importe) / SUM(SUM(p.importe)) OVER (), 1) AS pct_facturacion
FROM clientes c
JOIN pedidos  p ON p.cliente_id = c.cliente_id
WHERE p.estado = 'entregado'
GROUP BY c.tipo_cliente
ORDER BY ventas_usd DESC;

-- Clasificación de cada cliente por nivel de gasto (CASE sobre un agregado).
-- Los umbrales se eligieron según la distribución observada del gasto anual.
WITH gasto AS (
    SELECT c.cliente_id, c.nombre, COALESCE(SUM(p.importe), 0) AS gasto_usd
    FROM clientes c
    LEFT JOIN pedidos p
           ON p.cliente_id = c.cliente_id
          AND p.estado = 'entregado'
    GROUP BY c.cliente_id, c.nombre
)
SELECT
    nombre,
    gasto_usd,
    CASE
        WHEN gasto_usd >= 20000 THEN 'A - Estratégico'
        WHEN gasto_usd >=  3000 THEN 'B - Recurrente'
        ELSE                         'C - Ocasional'
    END AS segmento
FROM gasto
ORDER BY gasto_usd DESC;


-- =====================================================================
-- PREGUNTA 6. ¿Cuánto perdemos por cancelaciones y dónde?
-- Técnica: CASE dentro de SUM (agregación condicional).
-- Por qué: una cancelación es venta perdida; saber en qué categoría se
-- concentra orienta dónde revisar stock, plazos o precios.
-- =====================================================================
SELECT
    pr.categoria,
    COUNT(*)                                                       AS pedidos_totales,
    SUM(CASE WHEN p.estado = 'cancelado' THEN 1 ELSE 0 END)        AS pedidos_cancelados,
    SUM(CASE WHEN p.estado = 'cancelado' THEN p.importe ELSE 0 END) AS importe_perdido_usd,
    ROUND(100.0 * SUM(CASE WHEN p.estado = 'cancelado' THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                           AS tasa_cancelacion_pct
FROM pedidos   p
JOIN productos pr ON pr.producto_id = p.producto_id
GROUP BY pr.categoria
ORDER BY importe_perdido_usd DESC;
