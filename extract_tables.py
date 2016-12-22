#!/usr/bin/env python

import sys
import os
import re

sqlfile = sys.argv[1]

with open(sqlfile,'r') as sql:
	outputdir = re.sub('(?i)[^0-9a-z\.\_]','',os.path.basename(sqlfile))+'.tables'
	table = ''
	outfile = None
	if not os.path.exists(outputdir):
	    os.makedirs(outputdir)
	for line in sql:
		m = re.match('^-- Table structure for table .(.+).',line)

		if m:
			table = re.sub('(?i)[^0-9a-z\.\_]','',m.group(1))
			if outfile:
				outfile.close()
			outfile = open(os.path.join(outputdir,"%s.sql" % table),'w')

		if table != "" and outfile:
			outfile.write(line)