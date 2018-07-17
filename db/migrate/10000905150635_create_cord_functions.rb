class CreateCordFunctions < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.first_agg ( anyelement, anyelement )
      RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $1;
      $$;

      DROP AGGREGATE IF EXISTS public.FIRST (anyelement);
      CREATE AGGREGATE public.FIRST (
        sfunc = public.first_agg,
        basetype = anyelement,
        stype = anyelement
      );

      CREATE OR REPLACE FUNCTION public.last_agg ( anyelement, anyelement )
      RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $2;
      $$;

      DROP AGGREGATE IF EXISTS public.LAST (anyelement);
      CREATE AGGREGATE public.LAST (
        sfunc = public.last_agg,
        basetype = anyelement,
        stype = anyelement
      );
    SQL

    # LANGUAGE SQL => specifies language of function
    # IMMUTABLE => function is deterministic and can be cached
    # STRICT => if any argument if null, function returns null
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION public.first_agg ( anyelement, anyelement )
      DROP AGGREGATE IF EXISTS public.FIRST (anyelement);
      DROP FUNCTION public.last_agg ( anyelement, anyelement )
      DROP AGGREGATE IF EXISTS public.LAST (anyelement);
    SQL
  end
end
