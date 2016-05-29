import re
import sys

for filename in sys.argv[1:]:
    print 'converting', filename
    with open(filename) as fl:
        text = fl.read()
    converted = re.sub('(x|y)="(\d+\.\d+)"', lambda m: '%s="%s"' % (m.group(1), int(round(float(m.group(2))))), text)
    with open(filename, 'w') as fl:
        fl.write(converted)
