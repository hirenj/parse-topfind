#!/usr/bin/env python
import fileinput
import csv
import sys
import re

# This prevents prematurely closed pipes from raising
# an exception in Python
from signal import signal, SIGPIPE, SIG_DFL
signal(SIGPIPE, SIG_DFL)

def extract_ids(idstring):
	if (idstring == 'idstring'):
		return ["protease","substrate","position"]

	if idstring.find('at(') >= 0:
		return re.findall('\(([^\)]+)\)',idstring)
	else:
		ids = idstring.split('-')
		if (len(ids) < 3):
			return []

		return [ids[i] for i in [2,0,1]]


reader = csv.reader(fileinput.input(mode='rb'), delimiter=',')

writer = csv.writer(sys.stdout, quoting=csv.QUOTE_MINIMAL)

for row in reader:
	ids = extract_ids(row[0])
	if len(ids) == 3:
		row.append(ids[0])
		row.append(ids[1])
		row.append(ids[2])
		writer.writerow(row)