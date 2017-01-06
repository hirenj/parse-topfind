#!/bin/bash

version=$1

print_table() {
	sed -e 's/|/,/g' | ./csv2ascii.py - -w 160
}

if [ ! -e /tmp/topfind.zip ]; then
	# Cached get file ?
	curl -trycache -o /tmp/topfind.zip -ssS "http://clipserve.clip.ubc.ca/topfind/downloads/${version}.sql.zip"
fi


unzip -p /tmp/topfind.zip "${version}.sql" > topfind.sql

sqlfile=topfind.sql

tablespath=$(basename $sqlfile)

if [[ ! -d "${tablespath}.tables" || ! -f "${tablespath}.tables/cleavages.sql" ]]; then
	python extract_tables.py $sqlfile
fi

# We need to remove extra quote characters from the extracted fields
# since awk doesnt handle those fields well.

cat ${tablespath}.tables/cleavages.sql | python mysqldump_to_csv.py > cleavages.csv
head -n 2 cleavages.csv | print_table
cat ${tablespath}.tables/proteins.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > proteins.csv
head -n 2 proteins.csv | print_table
cat ${tablespath}.tables/evidences.sql | python mysqldump_to_csv.py | sed -e 's/"""[^"]*""/"/' | sed -e 's/,"[^"]*/,"/g' > evidences.csv
head -n 2 evidences.csv | print_table
cat ${tablespath}.tables/cleavage2evidences.sql | python mysqldump_to_csv.py > cleavage2evidences.csv
head -n 2 cleavage2evidences.csv | print_table
cat ${tablespath}.tables/cterms.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > cterms.csv
head -n 2 cterms.csv | print_table
cat ${tablespath}.tables/nterms.sql | python mysqldump_to_csv.py | sed -e 's/,"[^"]*/,"/g' > nterms.csv
head -n 2 nterms.csv | print_table
cat ${tablespath}.tables/cterm2evidences.sql | python mysqldump_to_csv.py > cterm2evidences.csv
head -n 2 cterm2evidences.csv | print_table
cat ${tablespath}.tables/nterm2evidences.sql | python mysqldump_to_csv.py > nterm2evidences.csv
head -n 2 nterm2evidences.csv | print_table

read_csv() {
	ids=$1
	csv=$2
	dbfile=$3
	sqlite3 $dbfile "CREATE TABLE $csv($ids)"
	awk -F',' -f extract_field.awk -v cols="$ids" "$csv.csv" | sed -e 's/|$//' -e 's/ | //' | sqlite3 $dbfile ".import /dev/stdin $csv"
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

sqlite3 topfind.db "select method,methodology,count(*) from evidences where method = 'electronic annotation' group by methodology" | print_table

echo "Methodologies for cleavages"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join cleavage2evidences on(evidences.id = cleavage2evidences.evidence_id) left join cleavages on (cleavage2evidences.cleavage_id = cleavages.id) join proteins on (cleavages.protease_id = proteins.id) where evidences.method != 'electronic annotation' group by evidences.methodology" | print_table

echo "Methodologies for Nterms"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join nterm2evidences on(evidences.id = nterm2evidences.evidence_id) left join nterms on (nterm2evidences.nterm_id = nterms.id) where evidences.method != 'electronic annotation' and nterms.idstring != '' group by evidences.methodology" | print_table

echo "Methodologies for Cterms"

sqlite3 topfind.db "select evidences.methodology,count(*) from evidences left join cterm2evidences on(evidences.id = cterm2evidences.evidence_id) left join cterms on (cterm2evidences.cterm_id = cterms.id) where evidences.method != 'electronic annotation' and cterms.idstring != '' group by evidences.methodology" | print_table

select_cleavage="select distinct cleavages.idstring,evidences.methodology,proteins.name,proteins.meropsfamily,proteins.meropssubfamily,proteins.meropscode from evidences left join cleavage2evidences on(evidences.id = cleavage2evidences.evidence_id) left join cleavages on (cleavage2evidences.cleavage_id = cleavages.id) join proteins on (cleavages.protease_id = proteins.id) where evidences.method != 'electronic annotation'"

select_cterms="select distinct cterms.idstring,evidences.methodology from evidences left join cterm2evidences on(evidences.id = cterm2evidences.evidence_id) left join cterms on (cterm2evidences.cterm_id = cterms.id) where evidences.method != 'electronic annotation' and cterms.idstring != ''"
select_nterms="select distinct nterms.idstring,evidences.methodology from evidences left join nterm2evidences on(evidences.id = nterm2evidences.evidence_id) left join nterms on (nterm2evidences.nterm_id = nterms.id) where evidences.method != 'electronic annotation' and nterms.idstring != ''"

if [ ! -d dist ]; then
	mkdir dist
fi

run_sql "$select_cleavage" topfind.db | python expand_idstring.py > dist/cleavages_data.csv
run_sql "$select_cterms" topfind.db | python expand_idstring.py > dist/cterms_data.csv
run_sql "$select_nterms" topfind.db | python expand_idstring.py > dist/nterms_data.csv

