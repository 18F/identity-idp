class PsqlStatsJob < ApplicationJob
  queue_as :default

  # gather data on bloat for each table
  # https://github.com/ioguix/pgsql-bloat-estimation/blob/master/table/table_bloat.sql
  QUERY = <<-SQL
  SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size,
    (tblpages-est_tblpages)*bs AS extra_size,
    CASE WHEN tblpages - est_tblpages > 0
      THEN 100 * (tblpages - est_tblpages)/tblpages::float
      ELSE 0
    END AS extra_pct, fillfactor,
    CASE WHEN tblpages - est_tblpages_ff > 0
      THEN (tblpages-est_tblpages_ff)*bs
      ELSE 0
    END AS bloat_size,
    CASE WHEN tblpages - est_tblpages_ff > 0
      THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
      ELSE 0
    END AS bloat_pct, is_na
  FROM (
    SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
      ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
      tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    FROM (
      SELECT
        ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
          - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
          - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
        ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
        toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      FROM (
        SELECT
          tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
          tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
          coalesce(toast.reltuples, 0) AS toasttuples,
          coalesce(substring(
            array_to_string(tbl.reloptions, ' ')
            FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
          current_setting('block_size')::numeric AS bs,
          CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
          24 AS page_hdr,
          23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
            + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
          sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
          bool_or(att.atttypid = 'pg_catalog.name'::regtype)
            OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
        FROM pg_attribute AS att
          JOIN pg_class AS tbl ON att.attrelid = tbl.oid
          JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
          LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
            AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
          LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
          WHERE NOT att.attisdropped AND ns.nspname='public' -- remove `AND ns.nspname='public'` to include system namespaces
          AND tbl.relkind in ('r','m')
        GROUP BY 1,2,3,4,5,6,7,8,9,10
        ORDER BY 2,3
      ) AS s
    ) AS s2
  ) AS s3
  ORDER BY schemaname, tblname;
  SQL

  def perform(_now)
    ar_result = ActiveRecord::Base.connection.exec_query(QUERY)
    IdentityJobLogSubscriber.reports_logger.info(
      {
        name: 'psql_bloat_statistics',
        table_data: ar_result.index_by { |r| r['tblname'] || 'none' },
      }.to_json,
    )

    true
  end
end
