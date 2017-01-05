#!/bin/bash

VERSION=$1

if [ ! -e /tmp/topfind.zip ]; then
	# Cached get file ?
	curl -o /tmp/topfind.zip -ssS "http://clipserve.clip.ubc.ca/topfind/downloads/$VERSION.sql.zip"
fi


unzip -p /tmp/topfind.zip "$VERSION.sql" > topfind.sql

SQLFILE=topfind.sql

TABLESPATH=$(basename $SQLFILE)

if [ ! -d "$TABLESPATH.tables" ]; then
	python extract_tables.py $SQLFILE
fi

# We need to remove extra quote characters from the extracted fields
# since awk doesnt handle those fields well.

cat $TABLESPATH.tables/cleavages.sql | python mysqldump_to_csv.py > cleavages.csv
head cleavages.csv
cat $TABLESPATH.tables/proteins.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > proteins.csv
head proteins.csv
cat $TABLESPATH.tables/evidences.sql | python mysqldump_to_csv.py | sed -e 's/"""[^"]*""/"/' | sed -e 's/,"[^"]*/,"/g' > evidences.csv
head evidences.csv
cat $TABLESPATH.tables/cleavage2evidences.sql | python mysqldump_to_csv.py > cleavage2evidences.csv
head cleavage2evidences.csv
cat $TABLESPATH.tables/cterms.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > cterms.csv
head cterms.csv
cat $TABLESPATH.tables/nterms.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > nterms.csv
head nterms.csv
cat $TABLESPATH.tables/cterm2evidences.sql | python mysqldump_to_csv.py > cterm2evidences.csv
head cterm2evidences.csv
cat $TABLESPATH.tables/nterm2evidences.sql | python mysqldump_to_csv.py > nterm2evidences.csv
head nterm2evidences.csv

read_csv() {
	ids=$1
	csv=$2
	dbfile=$3
	sqlite3 $dbfile "CREATE TABLE $csv($ids)"
	awk -F',' -f extract_field.awk -v cols="$ids" "$csv.csv" | sed -e 's/\|$//' -e 's/ \| //' | sqlite3 $dbfile ".import /dev/stdin $csv"
}

run_sql() {
	sql=$1
	db=$2
	sqlite3 -header -csv "$db" "$sql"
}

if [ -e topfind.db ]; then
	rm topfind.db
fi

read_csv "id,idstring,pos,protease_id" "cleavages" "topfind.db"
read_csv "id,ac,name,meropsfamily,meropssubfamily,meropscode" "proteins" "topfind.db"
read_csv "id,method,methodology" "evidences" "topfind.db"
read_csv "evidence_id,cleavage_id" "cleavage2evidences" "topfind.db"
read_csv "id,idstring" "nterms" "topfind.db"
read_csv "id,idstring" "cterms" "topfind.db"
read_csv "id,evidence_id,nterm_id" "nterm2evidences" "topfind.db"
read_csv "id,evidence_id,cterm_id" "cterm2evidences" "topfind.db"

echo "Evidence methodologies for electronic annotations"

sqlite3 topfind.db "select method,methodology,count(*) from evidences where method = 'electronic annotation' group by methodology"

echo "Methodologies for cleavages"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join cleavage2evidences on(evidences.id = cleavage2evidences.evidence_id) left join cleavages on (cleavage2evidences.cleavage_id = cleavages.id) join proteins on (cleavages.protease_id = proteins.id) where evidences.method != 'electronic annotation' group by evidences.methodology"

echo "Methodologies for Nterms"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join nterm2evidences on(evidences.id = nterm2evidences.evidence_id) left join nterms on (nterm2evidences.nterm_id = nterms.id) where evidences.method != 'electronic annotation' and nterms.idstring != '' group by evidences.methodology"

echo "Methodologies for Cterms"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join cterm2evidences on(evidences.id = cterm2evidences.evidence_id) left join cterms on (cterm2evidences.cterm_id = cterms.id) where evidences.method != 'electronic annotation' and cterms.idstring != '' group by evidences.methodology"

SELECT_CLEAVAGE="select distinct cleavages.idstring,evidences.methodology,proteins.name,proteins.meropsfamily,proteins.meropssubfamily,proteins.meropscode from evidences left join cleavage2evidences on(evidences.id = cleavage2evidences.evidence_id) left join cleavages on (cleavage2evidences.cleavage_id = cleavages.id) join proteins on (cleavages.protease_id = proteins.id) where evidences.method != 'electronic annotation'"

SELECT_CTERMS="select distinct cterms.idstring,evidences.methodology from evidences left join cterm2evidences on(evidences.id = cterm2evidences.evidence_id) left join cterms on (cterm2evidences.cterm_id = cterms.id) where evidences.method != 'electronic annotation' and cterms.idstring != ''"
SELECT_NTERMS="select distinct nterms.idstring,evidences.methodology from evidences left join nterm2evidences on(evidences.id = nterm2evidences.evidence_id) left join nterms on (nterm2evidences.nterm_id = nterms.id) where evidences.method != 'electronic annotation' and nterms.idstring != ''"

mkdir dist

run_sql "$SELECT_CLEAVAGE" topfind.db | python expand_idstring.py > dist/cleavages_data.csv
run_sql "$SELECT_CTERMS" topfind.db | python expand_idstring.py > dist/cterms_data.csv
run_sql "$SELECT_NTERMS" topfind.db | python expand_idstring.py > dist/nterms_data.csv

