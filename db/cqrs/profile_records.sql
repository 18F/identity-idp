CREATE TABLE profile_records%SUFFIX% (
    id serial NOT NULL,
    aggregate_id uuid NOT NULL,
    minted_at character varying,
    unencrypted_payload character varying,
    content character varying,
    CONSTRAINT profile_records_pkey%SUFFIX% PRIMARY KEY (id)
);

CREATE UNIQUE INDEX profile_records_keys%SUFFIX% ON profile_records%SUFFIX% USING btree (aggregate_id);
