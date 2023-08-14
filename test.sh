#!/bin/bash

set -e -o pipefail

xsh log info "xsql/parser"
[[ $(xsh xsql/parser select f1,f2 from A where f1 = x; set | grep ^Q_WHERE) == 'Q_WHERE=([0]="f1" [1]="=" [2]="x")' ]]

exit
